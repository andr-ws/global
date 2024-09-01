#!/bin/bash

# Raw T1w/T2w handling, minimal pre-processing (reorientation, neck crop, and brain extraction)
# Co-registration of T1w/T2w images


# instead of prompting the base of the path, I imagine running the code like this:
# bash this_script.sh path/2/dataset (where this is assigned as variable base) --resample=true (or =false)
# but resampling must be assigned as true or false to commence the script!


# Prompt the base path
read -p "Enter the base path of the dataset (e.g., ./path/2/data): " base

# Contains cross-purpose files (e.g., MNI spaces)
global=./imaging/global

# Base directory structure
rawdata="${base}/rawdata"
derivatives="${base}/derivatives"

# Parse optional resampling argument
resample=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --resample) resample=true ;;
    esac
    shift
done

find "${rawdata}" -type d -name 'sub-*' | sort -V | while read -r dir; do
  # Extract subject-id and create directory
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

    # Resample if specified
    if [ "$resample" = true ]; then
        echo "Resampling ${sub} to 1mm isotropic..."
        flirt \
        -in "${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_${modality}.nii.gz" \
        -ref "${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_${modality}.nii.gz" \
        -applyisoxfm 1.0 \
        -nosearch \
        -out "${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_iso_1mm_${modality}.nii.gz"

        # Use the resampled image for further processing
        modality_image="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_iso_1mm_${modality}.nii.gz"
    else
        # Use the non-resampled image for further processing
        modality_image="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_${modality}.nii.gz"
    fi
    
    echo "Brain extracting ${sub}..."
    mri_synthstrip \
    --image "${modality_image}" \
    --out "${modality_image%.*}_brain.nii.gz" \
    --mask "${modality_image%.*}_brain_mask.nii.gz"

  done # end modality loop

  # Determine the correct filenames for co-registration
  if [ "$resample" = true ]; then
    t1_image="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_iso_1mm_T1w_brain.nii.gz"
    t2_image="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_iso_1mm_T2w_brain.nii.gz"
    coreg_out="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_T2w_space-T1w_iso_1mm"
  else
    t1_image="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz"
    t2_image="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_T2w_brain.nii.gz"
    coreg_out="${derivatives}/data/${sub}/anat/${sub}_desc-bias_cor_T2w_space-T1w"
  fi

  # Co-register T2w to T1w MRI
  echo "Co-registering T2w to T1w for ${sub}..."
  antsRegistrationSyNQuick.sh \
  -d 3 \
  -f "${t1_image}" \
  -m "${t2_image}" \
  -o "${coreg_out}"

  # Rename co-registered T2w
  mv "${coreg_out}Warped.nii.gz" "${coreg_out}.nii.gz"
  
done # end participant loop
