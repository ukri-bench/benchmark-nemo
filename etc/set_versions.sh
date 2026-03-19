#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

## Sets required versions for the compiler, hdf5, netcdf and boost

export SYSTEM_NAME="archer2"

# Source platform specific variables
source etc/${SYSTEM_NAME}.sh

# export COMPILER="nvhpc"
# export COMPVER="24.11"
# #To create a spack environment name we need a compiler version string without a "." in it.
# export COMPVERP="24p11"

# export COMPILER="gcc"
# export COMPVER="11.2.0"
# #To create a spack environment name we need a compiler version string without a "." in it.
# export COMPVERP="11p20"

# export COMPILER="oneapi"
# export COMPVER="2025.0.1"
# #To create a spack environment name we need a compiler version string without a "." in it.
# export COMPVERP="2025p0p1"

export COMPILER="cce"
export COMPVER="15.0.0"
#To create a spack environment name we need a compiler version string without a "." in it.
export COMPVERP="15p00"

export H5VER="1.12.3"
export NCVER="4.9.0"
export NFVER="4.6.1"

if [[ ${COMPILER} == "oneapi" ]]; then
	export BOOSTVER="1.84.0"
else
	export BOOSTVER="1.85.0"
fi

export MPIIMPL="CRAY"
export MPICHVER="4.2.3"
export OMPIVER="5.0.6"
export IMPIVER="2021.14.0"

export PYVER="3.11"

export XIOSREV="head"
export XIOSVER="3"

export NMVER="5.0-RC"
