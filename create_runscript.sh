#!/usr/bin/env bash

ORIGIN_DIR=$(pwd)

CONFIG=$(spack location -i nemo)    # location of the configuration
CONFIG_DIR=EXP00                    # Configuration directory inside $CONFIG
RUN_NAME=TESTRG                     # Name of the run directory
NML_REF=namelist_cfg                # Namelist file to use from configuration directory

variants=$(spack find --format "{variants}" nemo)
if [[ $variants =~ "+mpi" ]]; then
    enable_mpi=1
else
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
#Start work done within NEMO_ROOT (for better or worse)
REF_DIR=${CONFIG}/${CONFIG_DIR}  # Path to the configuration directory
RUN_DIR=${ORIGIN_DIR}/${RUN_NAME}    # Path to the runtime directory

echo 'REF_DIR is' $REF_DIR
echo 'RUN_DIR is' $RUN_DIR

# Some checks on file availability
[ ! -f ${REF_DIR}/${NML_REF} ] && echo "No such namelist file \"${NML_REF}\"" && exit 1

#USING_XIOS=no
#GPU=
#cat $ORIGIN_DIR/build_nemo.sh | grep  '^USE_XIOS=yes' && USING_XIOS=yes
#cat $ORIGIN_DIR/build_nemo.sh | grep "^TRANS='omp_gpu_trans'" > /dev/null && GPU='export OMP_TARGET_OFFLOAD=MANDATORY'


## Copy and edit the input files
# NOTE- the run directory is always overwritten!
CONFIG_SRC=$(echo $variants | grep -o 'config=[^ ]*' | cut -d= -f2)


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
        #[[ ${USING_XIOS} == yes ]] && cp --remove-destination ${REF_DIR}/iodef.xml ${RUN_DIR}/iodef.xml
        ;;
esac

if [[ ${CONFIG_SRC} == 'ORCA2_ICE_PISCES' ]]; then
	mkdir -p $TMPDIR/inputs
	cd $TMPDIR/inputs
	wget -N https://gws-access.jasmin.ac.uk/public/nemo/sette_inputs/r4.2.0/ORCA2_ICE_v4.2.0.tar.gz
	[ ! -d ORCA2_ICE_v4.2.0 ] && tar -xvzf ORCA2_ICE_v4.2.0.tar.gz
	
	cd ${RUN_DIR}
	cp $TMPDIR/inputs/ORCA2_ICE_v4.2.0/* .
fi

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

## Write slurm job file  !!!!NOT XIOS CAPABLE YET!!!

echo 'Writing sbatch file to ' ${RUN_DIR}/run_nemo.sbatch

#Basic job submission ensuring we use an integer number of nodes.
#No GPU awareness
NPROC=$(($IPROC * $JPROC))            # Total no. of NEMO MPI processes

#Rule 1- NPROC must be an integer multiple of cores per node
REMAINDER=$(($NPROC % $CORES_PER_NODE))
echo Cores requested=$NPROC, Cores per node=$CORES_PER_NODE, Remainder=$REMAINDER

NNODE=$(perl -w -e "use POSIX; print ceil($NPROC/$CORES_PER_NODE), qq{\n}")
echo Required nodes=$NNODE
NTASKS=$(perl -w -e "use POSIX; print ceil($NPROC/$NNODE), qq{\n}")

#Further rules will be needed when we use OpenMP

cat << EOF > ${RUN_DIR}/run_nemo.sbatch
#!/usr/bin/env bash

# Slurm job options (job-name, compute nodes, job time)
#SBATCH --job-name=nemo_$RUN_NAME
#SBATCH --time=0:20:0
#SBATCH --nodes=$NNODE
#SBATCH --ntasks-per-node=$NTASKS
#SBATCH --cpus-per-task=1

# Replace [budget code] below with your budget code (e.g. t01)
#SBATCH --account=n02-ngarch
#SBATCH --partition=standard
#SBATCH --qos=standard

# Set the number of threads to 1
#   This prevents any threaded system libraries from automatically
#   using threading.
export OMP_NUM_THREADS=1

# Propagate the cpus-per-task setting from script to srun commands
#    By default, Slurm does not propagate this setting from the sbatch
#    options to srun commands in the job script. If this is not done,
#    process/thread pinning may be incorrect leading to poor performance
export SRUN_CPUS_PER_TASK=\$SLURM_CPUS_PER_TASK

# Launch the parallel job
#   Using 512 MPI processes and 128 MPI processes per node
#   srun picks up the distribution from the sbatch options

cd $RUN_DIR
srun --distribution=block:block --hint=nomultithread $RUN_DIR/nemo

EOF

echo "To run : sbatch ${RUN_DIR}/run_nemo.sbatch"
