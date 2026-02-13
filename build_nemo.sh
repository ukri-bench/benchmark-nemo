#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

## Builds Nemo

ORIGIN_DIR=$(pwd)

# Get required versions and directories
. ./etc/set_versions.sh
. ./etc/set_directories.sh

# Initialise spack
. $SPACK_PATH/share/spack/setup-env.sh

# Load the relevant environment previously created by build_spack,sh
spack env activate ${ENVDIR}/nemo_${COMPILER}_${COMPVERP}

CPREPROC=$(which cpp)
if [[ ${COMPILER} == "oneapi" ]]; then
	FCOMPILER=$(which mpiifx)
	LINKER=$(which mpiifx)
else
	FCOMPILER=$(which mpif90)
	LINKER=$(which mpif90)
fi

H5DIR=$(spack location -i hdf5%$COMPILER@${COMPVER})
NCDIR=$(spack location -i netcdf-c%$COMPILER@${COMPVER})
NFDIR=$(spack location -i netcdf-fortran%$COMPILER@${COMPVER})

export PYTHONPATH=${PSYDIR}/examples/nemo/scripts:${PYTHONPATH}

if [[ ! -d $NEMO_ROOT ]]; then
	git clone https://forge.nemo-ocean.eu/nemo/nemo.git ${NEMO_ROOT}
	cd ${NEMO_ROOT}
	git switch --detach ${NMVER}
fi

# User settings
#CONFIG_SRC='GOSI10p0.0_like_eORCA1'        # Name of the source configuration
CONFIG_SRC='ORCA2_ICE_PISCES'        # Name of the source configuration
CONFIG='BLDCFG'       # Name of the configuration to be built from ${CONFIG_SRC}
#TRANS='omp_gpu_trans'     # Unset or comment for no tranform
VERSION=5.0             # NEMO version

INPUT_DIR=              # Path to NEMO input files for the configuration (leave blank if no files required)
NEMO_USR_SRC_DIRS=()    # Directories containing extra NEMO source files (will be copied to source configuration MY_SRC directory)
NEMO_USR_CFG_DIRS=()    # Directories containing extra NEMO configuration files (replacement namelist_cfg, etc)
ARCH_EXTRA=             # Extra parameters to the arch file (required for cce)

USE_MPI=yes             # Compile for use with MPI?
USE_XIOS=no            # Compile for use with XIOS?
BUILD=yes               # Perform the NEMO build? If "no", only link required runtime files
USE_ICE=no

# For psyclone transformations
cp ${ORIGIN_DIR}/etc/sct_psyclone.sh ${NEMO_ROOT}/mk/ && chmod +x ${NEMO_ROOT}/mk/sct_psyclone.sh
cp ${ORIGIN_DIR}/etc/makenemo ${NEMO_ROOT} && chmod +x ${NEMO_ROOT}/makenemo

if [[ ${COMPILER} == 'nvhpc' ]]; then
	FCFLAGS="-i4 -Mr8 -Mnovect -Mflushz -Minline -Mnofma -O2 -gopt -traceback -march=${CPU_ARCH}"
	LDFLAGS="-i4 -Mr8 -Mnofma -march=${CPU_ARCH}"
	if [[ ${TRANS} == 'omp_cpu_trans' ]]; then
		FCFLAGS+=' -mp'
		LDFLAGS+=' -mp'
	elif [[ ${TRANS} == 'omp_gpu_trans' ]]; then
		if [[ ${CUDA_ARCH_VALUE} -ge 90 ]]; then
			FCFLAGS+=' -mp=gpu -gpu=mem:unified:nomanaged,math_uniform -Minfo=mp'
			LDFLAGS+=' -mp=gpu -gpu=mem:unified:nomanaged,math_uniform -Minfo=mp'
		else
			FCFLAGS+=' -mp=gpu -gpu=mem:managed,math_uniform -Minfo=mp'
			LDFLAGS+=' -mp=gpu -gpu=mem:managed,math_uniform -Minfo=mp'
		fi
	fi
elif [[ ${COMPILER} == 'gcc' ]]; then
	FCFLAGS="-fdefault-real-8 -O2 -funroll-all-loops -fcray-pointer -ffree-line-length-none -mcpu=${CPU_ARCH}"
	LDFLAGS="-fdefault-real-8 -mcpu=${CPU_ARCH}"
	if [[ ${TRANS} == 'omp_cpu_trans' ]]; then
		FCFLAGS+=' -fopenmp'
		LDFLAGS+=' -fopenmp'
	elif [[ ${TRANS} == 'omp_gpu_trans' ]]; then
		FCFLAGS+=' -fopenmp -foffload=nvptx-none'
		LDFLAGS+=' -fopenmp -foffload=nvptx-none'
	fi
elif [[ ${COMPILER} == 'oneapi' ]]; then
	FCFLAGS="-i4 -r8 -O2 -fp-model strict -xHost -fno-alias -march=${CPU_ARCH}"
	LDFLAGS="-i4 -r8 -march=${CPU_ARCH}"
	if [[ ${TRANS} == 'omp_cpu_trans' ]]; then
		FCFLAGS+=' -fiopenmp'
		LDFLAGS+=' -fiopenmp'
	elif [[ ${TRANS} == 'omp_gpu_trans' ]]; then
		FCFLAGS+=' -fiopenmp -fopenmp-targets=${GPU_ARCH}'
		LDFLAGS+=' -fiopenmp -fopenmp-targets=${GPU_ARCH}'
	fi
elif [[ ${COMPILER} == 'cce' ]]; then
	FCFLAGS="-em -s integer32 -s real64 -O2 -hvector_classic -hflex_mp=intolerant -N1023 -M878 -eF"
	LDFLAGS="-eF"
	ARCH_EXTRA="bld::tool::fc_modsearch -J"
fi

# Check source config exists
if [[ -d ${NEMO_ROOT}/cfgs/${CONFIG_SRC} ]] ; then
    CONFIG_ROOT=${NEMO_ROOT}/cfgs
    MAKENEMO_CFG=yes
elif [[ -d ${NEMO_ROOT}/tests/${CONFIG_SRC} ]] ; then
    CONFIG_ROOT=${NEMO_ROOT}/tests
    MAKENEMO_TST=yes
else
    echo "No such source configuration \"${CONFIG_SRC}\""
    exit 1
fi

if [[ $1 == 'clean' ]]; then
	rm -rf ${CONFIG_ROOT}/${CONFIG}
fi

ARCH=fort
export XIOS_PATH=${XIOSDIR}

# Let's generate our arch file
cat << EOF > ${NEMO_ROOT}/arch/arch-fort.fcm
%NCDFF_HOME          ${NFDIR}
%NCDFC_HOME          ${NCDIR}
%HDF5_HOME           ${H5DIR}
%XIOS_HOME           ${XIOSDIR}
%PSYCLONE_HOME       ${PSYDIR}

%NCDF_INC            -I%NCDFF_HOME/include
%NCDF_LIB            -L%NCDFF_HOME/lib -lnetcdff -L%NCDFC_HOME/lib -lnetcdf -L%HDF5_HOME/lib -lhdf5_hl -lhdf5 -lhdf5
%XIOS_INC            -I%XIOS_HOME/inc
%XIOS_LIB            -L%XIOS_HOME/lib -lxios -lstdc++

%CPP	             $CPREPROC -Dkey_nosignedzero
%FC                  $FCOMPILER
%PROD_FCFLAGS        $FCFLAGS
%DEBUG_FCFLAGS       -O0 -g -Minfo=all -i4 -r8
%FFLAGS              
%LD                  $FCOMPILER
%LDFLAGS             $LDFLAGS -Wl,-rpath=%HDF5_HOME/lib -Wl,-rpath=%NCDFF_HOME/lib -Wl,-rpath=%XIOS_HOME/lib
%FPPFLAGS            -P -traditional
%AR                  ar
%ARFLAGS             -rs
%MK                  gmake
%USER_INC            %XIOS_INC %NCDF_INC
%USER_LIB            %XIOS_LIB %NCDF_LIB
%DEBUG_FCFLAGS       -O0 -i4 -r8 -traceback
${ARCH_EXTRA}
EOF

NEMO_MY_SRC=${CONFIG_ROOT}/${CONFIG_SRC}/MY_SRC     # Path to the MY_SRC directory of the source configuration
RUN_DIR=${CONFIG_ROOT}/${CONFIG}/EXP00              # Path to the runtime directory of the built configuration

# XIOS settings
case ${USE_XIOS} in
    'yes')
        [ -z ${XIOS_PATH} ] && echo "XIOS_PATH must be defined if 'USE_XIOS=yes'" && exit 1
        XIOS_EXE=${XIOS_PATH}/bin/xios_server.exe
        [ ! -f ${XIOS_EXE} ] && echo "No XIOS executable found at \"${XIOS_EXE}\"" && exit 1
	[ "${XIOSVER}" -eq 3 ] && DEL_KEYS+=(key_xios)
	[ "${XIOSVER}" -eq 3 ] && ADD_KEYS+=(key_xios3)
        ;;
    'no')
        DEL_KEYS+=(key_xios key_iomput)
        ;;
esac

# MPI settings
if [[ ${USE_MPI} == 'no' ]] ; then
    case ${VERSION} in
        4.2*|5.0*)
            ADD_KEYS+=(key_mpi_off)
            ;;
        4.0*)
            DEL_KEYS+=(key_mpp_mpi)
            ;;
    esac
fi

if [[ ${ARCH} =~ 'nvfortran' ]] ; then
            ADD_KEYS+=(key_nosignedzero)
fi

if [[ ${USE_ICE} == 'no' ]] ; then
  DEL_KEYS+=(key_si3)
fi

if [[ ${CONFIG_SRC} == "ORCA2_ICE_PISCES" ]]; then
  DEL_KEYS+=(key_top)
fi

# Build NEMO executable
if [[ ${BUILD} == "yes" ]] ; then
    # Copy user src files to MY_SRC
    [[ ! -z ${NEMO_USR_SRC_DIRS} && ! -d ${NEMO_MY_SRC} ]] && mkdir -p ${NEMO_MY_SRC}
    for d in ${NEMO_USR_SRC_DIRS[*]} ; do
        if [ -d ${d} ] ; then
            for i in $(find ${d} -maxdepth 1 -type f) ; do
                cp -v ${i} ${NEMO_MY_SRC}
            done
        fi
    done

    # Run build
    cd ${NEMO_ROOT}
    echo -e "
               ${MAKENEMO_CFG:+-r ${CONFIG_SRC}} ${MAKENEMO_TST:+-a ${CONFIG_SRC}} -n ${CONFIG}
               "
    ./makenemo -j $NCPUS \
               -m ${ARCH} ${TRANS:+-p ${PSYDIR}/examples/nemo/scripts/$TRANS.py} \
               ${MAKENEMO_CFG:+-r ${CONFIG_SRC}} ${MAKENEMO_TST:+-a ${CONFIG_SRC}} -n ${CONFIG} \
               ${DEL_KEYS:+del_key "${DEL_KEYS[*]}"} ${ADD_KEYS:+add_key "${ADD_KEYS[*]}"}

fi

echo -e "STAGE 2 COMPLETED!"


# Link runtime files
if [ -d ${RUN_DIR} ] ; then
    cd ${RUN_DIR}

    # Input files
    if [[ ! -z ${INPUT_DIR} ]] ; then
        [ ! -d ${INPUT_DIR} ] && echo "No such input file directory \"${INPUT_DIR}\"" && exit 1
        for i in ${INPUT_DIR}/* ; do
            [ ! -f $(basename ${i}) ] && ln -sv ${i}
        done
    fi

    # XIOS executable
    if [[ ${USE_XIOS} == "yes" ]] ; then
        [ ! -f $(basename ${XIOS_EXE}) ] && ln -sv ${XIOS_EXE}
    fi

    # User cfg files
    for d in ${NEMO_USR_CFG_DIRS[*]} ; do
        if [ -d ${d} ] ; then
            for i in $(find ${d} -maxdepth 1 -type f) ; do
                ln -sfv ${i}
            done
        fi
    done
else
    echo "No such run directory ${RUN_DIR}"
    exit 1
fi
echo -e "STAGE 3 COMPLETED!"

echo Put extract the tarball to...
pwd


