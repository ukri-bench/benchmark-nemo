#!/usr/bin/env bash

export CORES_PER_NODE=128
export MAIN_DIR=/work/n02/n02/$USER
export TMPDIR=/mnt/lustre/a2fs-nvme/work/n02/n02/$USER
export SPACK_USER_CONFIG_PATH=${MAIN_DIR}/.spack
export SPACK_USER_CACHE_PATH=${TMPDIR}/spack

. ${MAIN_DIR}/spack/share/spack/setup-env.sh

# spack install py-f90nml%gcc@11
# spack load py-f90nml
