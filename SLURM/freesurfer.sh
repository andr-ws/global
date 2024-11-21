#!/bin/bash
#SBATCH --job-name=recon-fs_array
#SBATCH --partition=nodes
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32GB
#SBATCH --time=48:00:00
#SBATCH --array=1-T%N      # N is concurrent jobs to process with T being the total array size
#SBATCH --mail-type=END
#SBATCH --mail-user=luke.andrews@liverpool.ac.uk

# Code description: runs freesurfer on (synthetic) T1w MRI

# Requirements:
module avail apps/freesurfer/7.4.1
export FREESURFER_HOME=/mnt/data1/users/software/freesurfer/7.4.1
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/mnt/data1/users/a9ws/freesurfer

# Load subjects from file
subjects_file=/mnt/data1/users/a9ws/subjects_list_fs.txt
mapfile -t subjects < "$subjects_file"

# Determine the subject for this SLURM_ARRAY_TASK_ID
subject_path=${subjects[$SLURM_ARRAY_TASK_ID - 1]}
sub=$(basename "${subject_path}")

# Directory contains T1.nii which is desc-min_proc_T1w

mri_synthsr \
--i ${SUBJECTS_DIR}/${sub}/T1.nii \
--o ${SUBJECTS_DIR}/${sub}/sT1.nii \
--thr 16

# run recon-all
recon-all -s ${sub}_fs -i ${SUBJECTS_DIR}/${sub}/sT1.nii \
-all \
-qcache \
-openmp N # Match to the number of concurrent jobs
