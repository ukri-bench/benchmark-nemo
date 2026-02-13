#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

# Get required versions and directories
. ./etc/set_versions.sh
. ./etc/set_directories.sh

# Initialise spack
. $SPACK_PATH/share/spack/setup-env.sh

# Load the relevant environment previously created by build_spack,sh
spack env activate ${ENVDIR}/nemo_${COMPILER}_${COMPVERP}

echo Assumed node CPU resources...
echo Cores per socket = $CORES_PER_SOCKET
echo Sockets per node = $SOCKETS_PER_NODE
echo Cores per node = $CORES_PER_NODE

CONFIG=BLDCFG                       # Name of the configuration
CONFIG_DIR=EXP00                    # Configuration directory inside $CONFIG
RUN_NAME=TESTRG                     # Name of the run directory
NML_REF=namelist_cfg                # Namelist file to use from configuration directory

has_mpi=$(cat build_nemo.sh | grep USE_MPI=)
if [[ $has_mpi =~ "yes" ]]; then
    enable_mpi=1
elif [[ $has_mpi =~ "no" ]]; then
    enable_mpi=0
fi

# Parallel compute setup
IPROC=4                             # No. of NEMO MPI processes in the i (longitudinal) direction
JPROC=9                             # No. of NEMO MPI processes in the j (latitudinal) direction
XPROC=36                             # No. of XIOS servers (set to 0 if not using XIOS or if using attached mode)
RUNLEN=100                          # Run length in timesteps
OMP_THREADS=8

# Config options
TIMING=yes
STATS=yes

########### No user edits below here ###########

ORIGIN_DIR=$(pwd)

#Start work done within NEMO_ROOT (for better or worse)
cd $NEMO_ROOT

## Do some checks

# Check config exists
if [[ -d ${NEMO_ROOT}/cfgs/${CONFIG} ]] ; then
    CONFIG_ROOT=${NEMO_ROOT}/cfgs
elif [[ -d ${NEMO_ROOT}/tests/${CONFIG} ]] ; then
    CONFIG_ROOT=${NEMO_ROOT}/tests
else
    #Either $NEMO_ROOT or $CONFIG is wrong/missing
    echo "No such configuration \"${CONFIG}\""
    exit 1
fi

REF_DIR=${CONFIG_ROOT}/${CONFIG}/${CONFIG_DIR}  # Path to the configuration directory
RUN_DIR=${CONFIG_ROOT}/${CONFIG}/${RUN_NAME}    # Path to the runtime directory

echo 'REF_DIR is' $REF_DIR
echo 'RUN_DIR is' $RUN_DIR

# Some checks on file availability
[ ! -f ${REF_DIR}/${NML_REF} ] && echo "No such namelist file \"${NML_REF}\"" && exit 1

USING_XIOS=no
GPU=
cat $ORIGIN_DIR/build_nemo.sh | grep  '^USE_XIOS=yes' && USING_XIOS=yes
cat $ORIGIN_DIR/build_nemo.sh | grep "^TRANS='omp_gpu_trans'" > /dev/null && GPU='export OMP_TARGET_OFFLOAD=MANDATORY'


## Copy and edit the input files
# NOTE- the run directory is always overwritten!
cd $NEMO_ROOT

CONFIG_SRC=$(cat $ORIGIN_DIR/build_nemo.sh | grep "^CONFIG_SRC" | awk -F"=" '{split($2, arr, "#"); gsub(/["'\'']/, "", arr[1]); print arr[1]}' | xargs)

if [[ ${CONFIG_SRC} == 'ORCA2_ICE_PISCES' ]]; then
	mkdir -p $TMPDIR/inputs
	cd $TMPDIR/inputs
	wget -N https://gws-access.jasmin.ac.uk/public/nemo/sette_inputs/r4.2.0/ORCA2_ICE_v4.2.0.tar.gz
	[ ! -d ORCA2_ICE_v4.2.0 ] && tar -xvzf ORCA2_ICE_v4.2.0.tar.gz
	
	cd ${REF_DIR}
	cp $TMPDIR/inputs/ORCA2_ICE_v4.2.0/* .
fi

# Runtime directory is a copy of the configuration directory
# (all files copied as symlinks, except those to be edited)
case ${RUN_NAME} in
    BLD|EXP00|MY_SRC|WORK)
        echo "Run name \"${RUN_NAME}\" is a reserved string"
        exit 1
        ;;
    *)
        [ -d ${RUN_DIR} ] && rm -r ${RUN_DIR}   # Always clean the run directory
        cp -asTn ${REF_DIR} ${RUN_DIR}
        cp --remove-destination ${REF_DIR}/${NML_REF} ${RUN_DIR}/namelist_cfg
        [[ ${USING_XIOS} == yes ]] && cp --remove-destination ${REF_DIR}/iodef.xml ${RUN_DIR}/iodef.xml
        ;;
esac

if [[ ${CONFIG_SRC} =~ 'GOSI10p0.0_like_eORCA' ]]; then
	GRID=$(echo $CONFIG_SRC | grep -o 'eORCA.*')

	# Link all files from NEMO INPUTS to RUNDIR
	find ${NEMO_EXTRA_INPUTS}/ancil/${GRID}/link/ -type f -exec ln -s {} ${RUN_DIR} \;

	# Replace cn_dir in namsbc_blk block (needs escaping for python)
	f90nml -g namsbc_blk -v cn_dir=\""${NEMO_EXTRA_INPUTS}/forcing/JRA55/"\" ${RUN_DIR}/namelist_cfg ${RUN_DIR}/namelist_cfg
fi

# List optimal MPI decomposition
# f90nml -g nammpp -v ln_listonly=true ${RUN_DIR}/namelist_cfg ${RUN_DIR}/namelist_cfg

# Edit files for run
cd ${RUN_DIR}

#Edit in the number of processors
sed -r -i -e "s/(jpni[ ]*=[ ]*)([0-9]+)/\1${IPROC}/" \
          -e "s/(jpnj[ ]*=[ ]*)([0-9]+)/\1${JPROC}/" \
          -e "s/(nn_itend[ ]*=[ ]*)([0-9]+)/\1${RUNLEN}/" namelist_cfg

if [[ ${TIMING} == yes ]]; then
	f90nml -g namctl -v ln_timing=true namelist_cfg namelist_cfg
else
	f90nml -g namctl -v ln_timing=false namelist_cfg namelist_cfg
fi

if [[ ${STATS} == yes ]]; then
	f90nml -g namctl -v sn_cfctl%l_runstat=true namelist_cfg namelist_cfg
else
	f90nml -g namctl -v sn_cfctl%l_runstat=false namelist_cfg namelist_cfg
fi

case ${XPROC} in
    0) XIOS_SERVER=false ;;
    *) XIOS_SERVER=true ;;
esac
[[ ${USING_XIOS} == yes ]] && sed -r -i "s/(<variable id=\"using_server\"[^>]+>)(false|true)(<\/variable>)/\1${XIOS_SERVER}\3/" iodef.xml


## Write slurm job file  !!!!NOT XIOS CAPABLE YET!!!

echo 'Writing sbatch file to ' ${RUN_DIR}/run_nemo.sbatch

#Basic job submission ensuring we use an integer number of nodes.
#No GPU awareness
NPROC=$(($IPROC * $JPROC))            # Total no. of NEMO MPI processes

#Rule 1- NPROC must be an integer multiple of cores per node
REMAINDER=$(($NPROC % $CORES_PER_NODE))
echo Cores requested=$NPROC, Cores per node=$CORES_PER_NODE, Remainder=$REMAINDER

#if [ $REMAINDER -ne '0' ]; then
#	echo Requested processors must be integer number of nodes;
#	exit 1
#fi

NNODE=$(perl -w -e "use POSIX; print ceil($NPROC/$CORES_PER_NODE), qq{\n}")
echo Required nodes=$NNODE

#Further rules will be needed when we use OpenMP


if [[ $enable_mpi == 1 ]]; then
    if [[ ${USING_XIOS} == yes && ${XIOS_SERVER} == true ]] ; then
        COMMAND="mpirun -n $NPROC $RUN_DIR/nemo : -n $XPROC ./xios_server.exe"
    else
        COMMAND="mpirun -n $NPROC $RUN_DIR/nemo"
    fi
else
    COMMAND="$RUN_DIR/nemo"
fi

cat << EOF > ${RUN_DIR}/run_nemo.sbatch
#!/usr/bin/bash
#SBATCH --job-name=nemo_$RUN_NAME
#SBATCH --nodes=$NNODE
#SBATCH --time=02:00:00
#SBATCH --gpus=1
#SBATCH --exclusive

# Get required versions and directories
. $ORIGIN_DIR/etc/set_versions.sh
. $ORIGIN_DIR/etc/set_directories.sh

# Initialise spack
. $SPACK_PATH/share/spack/setup-env.sh

# Load the relevant environment previously created by build_spack,sh
spack env activate ${ENVDIR}/nemo_${COMPILER}_${COMPVERP}

#export OMP_NUM_THREADS=18
#numactl -m3 mpirun -n $NPROC -mca coll_hcoll_enable 0 $RUN_DIR/nemo

cd $RUN_DIR
$GPU
export OMP_NUM_THREADS=$OMP_THREADS
$COMMAND

EOF

echo "To run : sbatch ${RUN_DIR}/run_nemo.sbatch"
