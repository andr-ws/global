#! /bin/bash

# Code to process recon-all
export FREESURFER_HOME=/Applications/freesurfer/dev
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Base directory structure
base=/Users/neuero-239/Desktop/hcp
rawdata="${base}/rawdata"
derivatives="${base}/derivatives"

# Create and export FreeSurfer directory
mkdir -p "${derivatives}/freesurfer"
export SUBJECTS_DIR="${derivatives}/freesurfer"

# Copy a minimally pre-processed T1w MRI into the directory
find "${derivatives}/data" -type d -name 'sub-*' | sort -V | while read -r dir; do
  # Extract subject-id and create directory
  sub=$(basename "${dir}")
  
  # Make a subject directory
  mkdir -p "${SUBJECTS_DIR}/${sub}"
  
  for modality in T1w T2w; do
    cp "${dir}/anat/${sub}_desc-min_proc_${modality}.nii.gz" "${SUBJECTS_DIR}/${sub}/${modality}.nii.gz"
    gunzip "${SUBJECTS_DIR}/${sub}/${modality}.nii.gz"
  done

done

# Execute recon-all for 8 in parallel (with T2w)
ls "${SUBJECTS_DIR}"/*/*T1w.nii | parallel --jobs 8 recon-all -s {//}_fs -i {} \
-T2 {//}/T2w.nii \
-T2pial \
-all \
-qcache

# Overwite original directory with _fs
for dir in "${SUBJECTS_DIR}"/*_fs; do
  sub="$(basename ${dir})"
  new_sub="${sub/_fs/}"

  mv "${dir}/" "${SUBJECTS_DIR}/${new_sub}/"
done
