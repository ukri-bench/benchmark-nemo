#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

## Sets directories to be used
mkdir -p ${MAIN_DIR}/scratch

# set System Name
$(cat etc/set_versions.sh | grep SYSTEM_NAME= | sed 's/"//g')

# Load config
source etc/${SYSTEM_NAME}.sh

export SPACK_PATH=${MAIN_DIR}/spack
export WORK_DIR=${MAIN_DIR}/scratch
export TMPDIR=${MAIN_DIR}/scratch
export ENVDIR=${WORK_DIR}/env
export SPACK_USER_CONFIG_PATH=${MAIN_DIR}/.spack
export SPACK_USER_CACHE_PATH=${TMPDIR}/spack

export XIOSDIR=$WORK_DIR/xios-${COMPILER}${COMPVERP}
export NEMO_ROOT=$WORK_DIR/nemo
export PSYDIR=$WORK_DIR/psyclone

export NEMO_EXTRA_INPUTS=/projects/ng-arch/NEMO-INPUTS
