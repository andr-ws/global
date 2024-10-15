#!/bin/bash

#SBATCH --job-name=recon-all_raghoo2k
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=8  # Adjust according to your needs
#SBATCH --mem=24GB         # Adjust according to your needs
#SBATCH --time=48:00:00    # Adjust according to your needs

# Base directory structure
basedir="/users/raghoo2k/volatile/Der"

# Create and export FreeSurfer directory
mkdir -p "${basedir}/freesurfer"
export SUBJECTS_DIR="${basedir}/freesurfer"

# Copy a minimally pre-processed T1w MRI into the directory
find "${basedir}" -type d -name 'sub-*' | sort -V | while read -r dir; do
# Extract subject-id and create directory
sub=$(basename "${basedir}")

# Make a subject directory
mkdir -p "${SUBJECTS_DIR}/${sub}"

cp "${basedir}/anat/${sub}_T1w.nii.gz" \
"${SUBJECTS_DIR}/${sub}/T1w.nii.gz"

gunzip "${SUBJECTS_DIR}/${sub}/T1w.nii.gz"

# Execute recon-all
recon-all -s ${sub} -i T1w.nii -all

done
