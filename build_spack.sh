#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

## Creates the spack environment needed for NEMO (and XIOS)

# Get required versions and directories
. ./etc/set_versions.sh
. ./etc/set_directories.sh

# Initialise spack
. $SPACK_PATH/share/spack/setup-env.sh 

# Set up the compiler to be generally available, not just in the environment
if [[ ${COMPILER} == 'nvhpc' ]]; then
	COMP="${COMPILER}@${COMPVER}"
	COMPPATH="Linux_$(arch)/${COMPVER}/compilers/"
elif [[ ${COMPILER} == 'gcc' ]]; then
	COMP="${COMPILER}@${COMPVER}"
	#TODO: COMPPATH
elif [[ ${COMPILER} == 'oneapi' ]]; then
	COMP="intel-oneapi-compilers@${COMPVER}"
	#TODO: COMPPATH
elif [[ ${COMPILER} == 'cce' ]]; then
	COMP="${COMPILER}@${COMPVER}"
	# sed -i "s/^+    .*/+    version(\"${COMPVER}\")/" ./etc/cce.patch
	# patch --forward ${SPACK_PATH}/var/spack/repos/builtin/packages/cce/package.py ./etc/cce.patch
fi

if [ -z "${INSTALL_COMP}" ] || [ "${INSTALL_COMP}" == "1" ]; then
	spack install $COMP
	spack load $COMP
	#In case this is the first time the compiler has been installed on this platform, tell spack to add it
	spack compiler find "$(spack location -i $COMP)/${COMPPATH}"
fi

# Create the environment. Note environment names cannot contain '.' or anything interested
spack env activate -p --create ${ENVDIR}/nemo_${COMPILER}_${COMPVERP}
# Apply a fix for netcdf-c
. ./etc/spack_fix_netcdfc.sh

if [[ ${MPIIMPL} == "MPICH" ]]; then
	spack add mpich@${MPICHVER}%${COMPILER}@${COMPVER} ${MPICHOPTS} ^yaksa%${COMPILER}@${COMPVER}
elif [[ ${MPIIMPL} == "OMPI" ]]; then
	spack add openmpi@${OMPIVER}%${COMPILER}@${COMPVER}
elif [[ ${MPIIMPL} == "INTEL" ]]; then
	spack add intel-oneapi-mpi@${IMPIVER}%${COMPILER}@${COMPVER}
elif [[ ${MPIIMPL} == "CRAY" ]]; then
	spack add cray-mpich%${COMPILER}@${COMPVER}
fi

spack add hdf5@${H5VER}%$COMPILER@${COMPVER} +cxx +shared +fortran +hl +mpi ~szip ~threadsafe
spack add netcdf-c@${NCVER}%$COMPILER@${COMPVER} +mpi +shared ~parallel-netcdf  ~blosc ~szip ~zstd
spack add netcdf-fortran@${NFVER}%$COMPILER@${COMPVER} +shared
spack add boost@${BOOSTVER}%$COMPILER@${COMPVER}
spack add subversion
spack add perl-uri
spack add nccmp
spack add python
spack add py-pip
spack add py-f90nml
spack add gdb # Add GDB to the spack environment in case cuda-gdb fails to work

spack install


