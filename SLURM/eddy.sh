#!/bin/bash

#SBATCH --job-name=ppmi_eddy
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8  # 8 cpus to match eddy nthr
#SBATCH --mem=32GB         # Adjust according to your needs
#SBATCH --time=24:00:00    # Adjust according to your needs
#SBATCH --array=1-N%T      # Process N concurrent jobs with T as the total array size
#SBATCH --mail-type=END
#SBATCH --mail-user=luke.andrews@liverpool.ac.uk

# Code description: 
# Runs eddy through the CPU (GPU version is bugged) following synb0.

# Requirements:

module load apps/fsl/6.0.7.9

# Text file with full subject paths
subjects_file=/mnt/data1/users/a9ws/subjects_list_sb0.txt
mapfile -t subjects < "$subjects_file"

# Determine the subject for this SLURM_ARRAY_TASK_ID
subject_path=${subjects[$SLURM_ARRAY_TASK_ID - 1]}
sub=$(basename "${subject_path}")

mkdir ${subject_path}/eddy
bet ${subject_path}/synb0/OUTPUTS/b0_all_topup ${subject_path}/eddy/b0_topup_brain -m 

eddy \
--imain=${subject_path}/synb0/INPUTS/${sub}_dwi.nii.gz \
--mask=${subject_path}/eddy/b0_topup_brain_mask \
--acqp=${subject_path}/synb0/INPUTS/acqparams.txt \
--index=${subject_path}/synb0/INPUTS/index.txt \
--bvecs=${subject_path}/synb0/INPUTS/${sub}_dwi.bvec \
--bvals=${subject_path}/synb0/INPUTS/${sub}_dwi.bval \
--topup=${subject_path}/synb0/OUTPUTS/topup \
--out=${subject_path}/eddy/${sub}_dwi_edc \
--nthr=8 \
--repol
