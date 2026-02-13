#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

export MAIN_DIR=/work/n02/n02/addy

#Grace GH200 CPUs (Isambard-AI)
export CORES_PER_SOCKET=64
export SOCKETS_PER_NODE=2
export CORES_PER_NODE=$(($CORES_PER_SOCKET*$SOCKETS_PER_NODE))
export NCPUS=16 #Better for compilation performance

export CPU_ARCH="znver2"
export ROCM_ARCH_VALUE="gfx90a"

# Confirm if you need to build compiler through spack
export INSTALL_COMP=0

# MPI options
export MPICHOPTS="+fortran +slurm ~hydra pmi=cray netmod=ofi"
