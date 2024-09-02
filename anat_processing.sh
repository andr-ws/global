#!/bin/bash

# Raw T1w/T2w handling, minimal pre-processing (reorientation, neck crop, and brain extraction)
# Co-registration of T1w/T2w images

# Ensure the script is run with at least one argument
if [ "$#" -eq 0 ]; then
    echo "Usage: bash $0 <path/to/dataset> [--resample=true|false]"
    exit 1
fi

# Base path of the dataset
base=$1

# Validate base path
if [ ! -d "$base" ]; then
    echo "Error: The provided base path does not exist."
    exit 1
fi

# Optional resampling argument
resample=false
for arg in "$@"; do
    case $arg in
        --resample=*)
            resample="${arg#*=}"
            ;;
    esac
done

# Validate resample argument
if [ "$resample" != "true" ] && [ "$resample" != "false" ]; then
    echo "Error: --resample must be 'true' or 'false'."
    exit 1
fi

# Define directories
global="./imaging/global"
rawdata="${base}/rawdata"
derivatives="${base}/derivatives"

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
  done

  for image in min_proc bias_cor; do
    # Co-register T2w to T1w MRI
    echo "Co-registering T2w to T1w for ${sub}..."
    antsRegistrationSyNQuick.sh \
    -d 3 \
    -f "${derivatives}/data/${sub}/anat/${sub}_desc-${image}_T1w.nii.gz" \
    -m "${derivatives}/data/${sub}/anat/${sub}_desc-${image}_T2w.nii.gz" \
    -o "${derivatives}/data/${sub}/anat/${sub}_desc-${image}_T2w_space-T1w"

    mv "${derivatives}/data/${sub}/anat/${sub}_desc-${image}_T2w_space-T1wWarped.nii.gz" \
    "${derivatives}/data/${sub}/anat/${sub}_desc-${image}_T2w_space-T1w.nii.gz"
  done

  for image in min_proc bias_cor 

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



  # Rename co-registered T2w
  
  
done # end participant loop
