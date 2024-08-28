#!/bin/bash

# Code to compute xfms for dwi to structural to mni (05mm)

# Prompt the base path
read -p "Enter the base path of the dataset (e.g., ./path/2/data): " base

# Contains cross-purposes files (i.e., MNI spaces)
global=./imaging/global

# Base directory structure
rawdata="${base}/rawdata"
derivatives="${base}/derivatives"

find "${derivatives}/data" -type d -name 'sub-*' | sort -V | while read -r dir; do
	sub=$(basename "${dir}")

	# define xfm directory
	xfm="${derivatives}/data/${sub}/xfms"

	mkdir -p \
	"${xfm}/coreg/ANTs" \
	"${xfm}/coreg/FSL" \
	"${xfm}/norm/ANTs" \
	"${xfm}/norm/FSL"

	# Create a b0 image from edc data
	dwiextract \
	"${derivatives}/data/${sub}/eddy/${sub}_dwi_edc.nii.gz" - -bzero \
	-fslgrad \
	"${dwi}/${sub}/eddy/${sub}_dwi_edc.eddy_rotated_bvecs" \
	"${raw}/${sub}/dwi/${sub}_dwi.bval" \
	| mrmath - mean "${dwi}/${sub}/eddy/${sub}_dwi_edc_b0.nii.gz" \
	-axis 3

	# Brain extract the edc b0
	bet \
	"${dwi}/${sub}/eddy/${sub}_dwi_edc_b0.nii.gz" \
	"${dwi}/${sub}/eddy/${sub}_dwi_edc_b0_brain.nii.gz"

	# Coregister b0-T1w
	antsRegistrationSyN.sh \
	-d 3 \
	-f "${anat}/${sub}/${sub}_desc-bias_cor_T1w_brain.nii.gz" \
	-m "${dwi}/${sub}/eddy/${sub}_dwi_edc_b0_brain.nii.gz" \
	-o "${xfm}/coreg/ANTs/${sub}_b0-T1w_" \
	-t r 2>&1 | tee "${xfm}/${sub}/coreg/ANTs/${sub}_desc-b0_T1w_ants_output.log"

	# Check for the specific error in the log output
	if grep -q "All samples map outside moving image buffer" "${xfm}/coreg/ANTs/${sub}_ants_output.log"; then
		echo "ANTs registration failed due to insufficient overlap. Proceeding with FLIRT epi_reg instead..."

		# Clear failed ANTs runs
		rm "${xfm}/${sub}/coreg/ANTs/"*b0*

		epi_reg \
		--epi="${dwi}/${sub}/eddy/${sub}_dwi_edc_b0_brain.nii.gz" \
		--t1="${anat}/${sub}/${sub}_desc-bias_cor_T1w.nii.gz" \
		--t1brain="${data}/${sub}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz" \
		--out="${xfm}/coreg/FSL/${sub}_desc-b0_T1w_affine"
				
		# Convert the b0-T1w xfm (FSL to ANTs affine)
		c3d_affine_tool \
		-ref "${data}/${sub}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz" \
		-src "${dwi}/${sub}/eddy/${sub}_dwi_edc_b0_brain.nii.gz" \
		"${xfm}/coreg/FSL/${sub}_desc-b0_T1w_affine.mat" \
		-fsl2ras \
		-oitk "${xfm}/${sub}/coreg/ANTs/${sub}_desc-b0_T1w_0GenericAffine.mat"

	else
		echo "ANTs registration completed successfully. Skipping FLIRT-based fallback."
		
		# Convert the b0-T1w ANTs to FSL conversion (affines)
		c3d_affine_tool \
		-ref "${data}/${sub}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz" \
		-src "${dwi}/${sub}/eddy/${sub}_dwi_edc_b0_brain.nii.gz" \
		-itk "${xfm}/coreg/ANTs/${sub}_desc-b0-T1w_0GenericAffine.mat" \
		-ras2fsl \
		-o "${xfm}/${sub}/coreg/FSL/${sub}_desc-b0_T1w_affine.mat"
	fi

	# T1w-05mm warp
	antsRegistrationSyN.sh \
	-d 3 \
	-f "${global}/mni/MNI152_T1_05mm_brain.nii.gz" \
	-m "${data}/${sub}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz" \
	-o "${xfm}/norm/ANTs/${sub}_desc-T1w-MNI05mm_"

	# ANTs to FSL (warps)
	wb_command \
	-convert-warpfield -from-itk \
	"${xfm}/norm/ANTs/${sub}_desc-T1w_MNI05mm_1Warp.nii.gz" \
	-to-fnirt \
	"${xfm}/norm/FSL/${sub}_desc-T1w_MNI05mm_warp.nii.gz" \
	"${global}/mni/MNI152_T1_05mm_brain.nii.gz"

	# Compose xfms (b0-T1w-05mm; FSL affine + warp)
	convertwarp \
	--ref="${global}/mni/MNI152_T1_05mm_brain.nii.gz" \
	--premat="${xfm}/coreg/FSL/${sub}_desc-b0_T1w_affine.mat" \
	--warp1="${xfm}/norm/FSL/${sub}_desc-T1w_MNI05mm_warp.nii.gz" \
	--out="${xfm}/norm/FSL/${sub}_desc-b0_T1w_MNI05mm_affwarp.nii.gz"

	# Generate inverse (05mm-T1w-b0; FSL affine + warp)
	invwarp \
	--ref="${dwi}/${sub}/eddy/${sub}_dwi_edc_b0_brain.nii.gz" \
	--warp="${xfm}/norm/FSL/${sub}_desc-b0_T1w_MNI05mm_affwarp.nii.gz" \
	--out="${xfm}/norm/FSL/${sub}_desc-MNI05mm_T1w_b0_affwarp.nii.gz"
done
