#!bin/bash

# Raw T1w/T2w handling, minimal pre-processing (reorientation, neck crop and brain extraction)
# Co-registration of T1w/T2w images

# Prompt the base path
read -p "Enter the base path of the dataset (e.g., ./path/2/data): " base

# Contains cross-purposes files (i.e., MNI spaces)
global=./imaging/global

# Base directory structure
rawdata="${base}/rawdata"
derivatives="${base}/derivatives"

find "${rawdata}" -type d -name 'sub-*' | sort -V | while read -r dir; do
  # extract subject-id and create directory
  sub=$(basename "${dir}")

  mkdir -p "${derivatives}/data/${sub}/anat"

  for modality in T1w T2w; do

    echo "Reorienting and cropping ${sub}..."
    fslreorient2std \
    "${rawdata}/${sub}/anat/${sub}_${modality}.nii.gz" \
    "${derivatives}/data/${sub}/anat/${sub}_desc-min_proc_${modality}.nii.gz"
	
    robustfov \
    -i "${derivatives}/data/${sub}/anat/${sub}_desc-min_proc_${modality}.nii.gz" \
    -r "${derivatives}/data/${sub}/anat/${sub}_desc-min_proc_${modality}.nii.gz"

    echo "Biasfield correcting ${sub}..."
    N4BiasFieldCorrection \
    -d 3 \
    -i "${derivatives}/data/${sub}/anat/${sub}_desc-min_proc_${modality}.nii.gz" \
    -o "${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_${modality}.nii.gz"

    # brain extraction
    echo "Brain extracting (minimal and biasfield) for ${sub}..."
    for img in min_proc bias_cor; do
      mri_synthstrip \
      --image "${derivatives}/data/${sub}/anat/${sub}_desc-${img}_${modality}.nii.gz" \
      --out "${derivatives}/data/${sub}/anat/${sub}_desc-${img}_${modality}_brain.nii.gz" \
      --mask "${derivatives}/data/${sub}/anat/${sub}_desc-${img}_${modality}_brain_mask.nii.gz"
    done # end brain extraction
  done # end modality loop

  # Co-register T2w-T1w MRI
  antsRegistrationSyNQuick.sh \
  -d 3 \
  -f "${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz" \
  -m "${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_T2w_brain.nii.gz" \
  -o "${derivatives}/data/${sub}/anat/${sub}/${SUB}_desc-bias_cor_T2w_space-T1w_"

  # Rename co-registered T2
  mv "${derivatives}/data/${sub}/anat/${sub}/${SUB}_desc-bias_cor_T2w_space-T1w_Warped.nii.gz" \
  "${derivatives}/data/${sub}/anat/${sub}/${SUB}_desc-bias_cor_T2w_space-T1w.nii.gz"
  
done # end participant loop
