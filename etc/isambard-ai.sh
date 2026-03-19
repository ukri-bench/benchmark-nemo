#!/usr/bin/env bash

# Copyright 2026 Aditya Sadawarte and Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

export MAIN_DIR=$HOME

#Grace GH200 CPUs (Isambard-AI)
export CORES_PER_SOCKET=72
export SOCKETS_PER_NODE=4
export CORES_PER_NODE=$(($CORES_PER_SOCKET*$SOCKETS_PER_NODE))
export NCPUS=16 #Better for compilation performance

export CPU_ARCH="neoverse-v2"
export CUDA_ARCH_VALUE=90

# MPI options
export MPICHOPTS="+cuda +fortran +slurm ~hydra cuda_arch=${CUDA_ARCH_VALUE} pmi=cray netmod=ofi ^cuda+dev"
