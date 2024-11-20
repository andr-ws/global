#! /bin/bash

#SBATCH --job-name=ppmi_dwi
#SBATCH --nodes=1                      # Single node
#SBATCH --ntasks=1                     # One task per array job
#SBATCH --cpus-per-task=4              # Number of CPU cores per task
#SBATCH --mem=360GB                     # Memory per task (adjust as needed)
#SBATCH --time=48:00:00                # Maximum runtime (D-HH:MM:SS)
#SBATCH --array=1-N%T                # Job array, max N concurrent jobs with T the size of the array

# Requirements:

# Synb0 path
synb0_path=/mnt/data1/users/a9ws/synb0-disco-v3.1.simg
singularity_path=/mnt/data1/users/software/singularity/singularity-2.5.2-install/bin/singularity

data=/mnt/data1/users/a9ws/synb0

# License path
fs_license=/mnt/data1/users/a9ws/license.txt

# Subject full path text file
subjects_file=/mnt/data1/users/a9ws/subjects_list_sb0.txt
mapfile -t subjects < "$subjects_file"

# Determine the subject for this SLURM_ARRAY_TASK_ID
subject_path=${subjects[$SLURM_ARRAY_TASK_ID - 1]}
sub=$(basename "${subject_path}")

# Run Synb0-disco
${singularity_path} exec -e \
-B ${data}/${sub}/dwi/synb0/INPUTS/:/INPUTS \
-B ${data}/${sub}/dwi/synb0/OUTPUTS/:/OUTPUTS \
-B ${fs_license}:/extra/freesurfer/license.txt \
"${synb0_path}" \
/extra/pipeline.sh --stripped
