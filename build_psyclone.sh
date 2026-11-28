#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

## Installs PSyclone


# Get required versions and directories
. ./etc/set_versions.sh
. ./etc/set_directories.sh

# Initialise spack
. $SPACK_PATH/share/spack/setup-env.sh 

# Load the relevant environment previously created by build_spack,sh
spack env activate ${ENVDIR}/nemo_${COMPILER}_${COMPVERP}

# Check out PSyclone at the revision set in etc/set_versions.sh
rm -rf ${PSYDIR}
git clone https://github.com/stfc/PSyclone.git ${PSYDIR} || exit 1
cd ${PSYDIR}
git checkout --detach ${PSYREV} || exit 1

# install
python -m pip install .

