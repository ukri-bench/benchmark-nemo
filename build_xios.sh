#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

## Builds XIOS

# Get required versions and directories
. ./etc/set_versions.sh
. ./etc/set_directories.sh

# Initialise spack
. $SPACK_PATH/share/spack/setup-env.sh 

# Load the relevant environment previously created by build_spack,sh
spack env activate ${ENVDIR}/nemo_${COMPILER}_${COMPVERP}

if [[ ${COMPILER} == 'oneapi' ]]; then
	CCOMPILER=$(which mpiicx)
	FCOMPILER=$(which mpiifx)
	LINKER=$(which mpiifx)
else
	CCOMPILER=$(which mpicxx)
	FCOMPILER=$(which mpif90)
	LINKER=$(which mpif90)
fi

# Set Directories
H5DIR=$(spack location -i hdf5%$COMPILER@${COMPVER})
NCDIR=$(spack location -i netcdf-c%$COMPILER@${COMPVER})
NFDIR=$(spack location -i netcdf-fortran%$COMPILER@${COMPVER})
BOOSTDIR=$(spack location -i boost%$COMPILER@${COMPVER})
CURLDIR=$(spack location -i curl)

# Check out XIOS3
cd $WORK_DIR
rm -rf ${XIOSDIR}
[ "${XIOSVER}" -eq 3 ] && svn co http://forge.ipsl.jussieu.fr/ioserver/svn/XIOS3/trunk@${XIOSREV} xios_working_copy
[ "${XIOSVER}" -eq 2 ] && svn co http://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/trunk xios_working_copy
cd xios_working_copy

# Patching XIOS
sed -i "s?//#include <cstdint>?#include <cstdint>?g" extern/remap/src/earcut.hpp

if [[ ${COMPILER} == 'nvhpc' ]]; then
	BASECFLAGS='-fPIC -std=c++11 -D__NONE__'
	BASELD='-lstdc++'
	BASEFFLAGS='-fPIC -D__NONE__'
elif [[ ${COMPILER} == 'gcc' ]]; then
	BASECFLAGS='-fPIC -std=c++11 -D__XIOS_EXCEPTION -pthread'
	BASEFFLAGS='-fPIC -D__NONE__ -ffree-line-length-2048'
	BASELD='-lstdc++ -pthread'
elif [[ ${COMPILER} == 'oneapi' ]]; then
	BASECFLAGS='-fPIC -std=c++11 -D__XIOS_EXCEPTION -pthread'
	BASEFFLAGS='-fPIC -D__NONE__'
	BASELD='-lstdc++ -pthread'
fi

#Create .fcm file
cat << EOF > arch/arch-$SYSTEM_NAME.fcm
%CCOMPILER          $CCOMPILER
%FCOMPILER          $FCOMPILER
%LINKER             $LINKER

%BASE_CFLAGS    ${BASECFLAGS}
%PROD_CFLAGS    -O1 -DBOOST_DISABLE_ASSERTS -w -v
%DEV_CFLAGS     -g -O2
%DEBUG_CFLAGS   -DBZ_DEBUG -g

%BASE_FFLAGS    ${BASEFFLAGS}
%PROD_FFLAGS    -O1
%DEV_FFLAGS     -g -O2 -traceback
%DEBUG_FFLAGS   -g -traceback

%BASE_INC       -D__NONE__
%BASE_LD        ${BASELD}

%CPP            cpp -EP
%FPP            cpp -P
%MAKE           make
EOF

#Create .path file
cat << EOF > arch/arch-$SYSTEM_NAME.path
NETCDF_INCDIR="-I ${NCDIR}/include -I ${NFDIR}/include "
NETCDF_LIBDIR="-L ${NCDIR}/lib -L ${NFDIR}/lib "
NETCDF_LIB="-lnetcdf -lnetcdff"

MPI_INCDIR="-I${CURLDIR}/include "
MPI_LIBDIR="-L${CURLDIR}/lib "
MPI_LIB="-lcurl"

HDF5_INCDIR="-I${H5DIR}/include -I${CURLDIR}/include "
HDF5_LIBDIR="-L${H5DIR}/lib -L${CURLDIR}/lib "
HDF5_LIB="-lhdf5_hl -lhdf5 -lz -lcurl"

BOOST_INCDIR="-I${BOOSTDIR}/include"
BOOST_LIBDIR="-L${BOOSTDIR}/lib"
BOOST_LIB=""
EOF

#Do the actual build
./make_xios --arch $SYSTEM_NAME --prod --build_path ${XIOSDIR} --job $NCPUS
