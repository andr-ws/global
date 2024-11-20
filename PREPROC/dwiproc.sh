#!/bin/bash

# Code to setup dwi directory and perform minimal preprocessing. 
# Requires user input of the highest level directory (contains sourcedata, rawdata etc.)

# Prompt the base path
read -p "Enter the base path of the dataset (e.g., ./path/2/data): " base

# Base directory structure
raw="${base}/rawdata"
der="${base}/derivatives"
dwi="${der}/data/dwi"

find "${raw}" -type d -name 'sub-*' | sort -V | while read -r dir; do
	# extract subject-id and create directory
	sub=$(basename "${dir}")

	if [ ! -d "${dir}/dwi" ]; then
		echo "Skipping ${sub} as no patient has no dwi directory"
		continue
	fi

	mkdir -p "${dwi}/${sub}"
	
	# Copy bval and bvec files	
	cp "${raw}/${sub}/dwi/${sub}_dwi.bval" "${dwi}/${sub}/"
	cp "${raw}/${sub}/dwi/${sub}_dwi.bvec" "${dwi}/${sub}/"

	# Create index file (no. of vols in the dwi set)
	vol_count=$(wc -w < "${dwi}/${sub}/${sub}_dwi.bval")
	index=$(yes 1 | head -n "${vol_count}" | tr '\n' ' ')
	echo "${index}" > "${dwi}/${sub}/index.txt"

	# Create acquisition paramaters file for edc
	dwi_json="${raw}/${sub}/dwi/${sub}_dwi.json"
	if grep -q "j-" "${dwijson}"; then 
		ped=-1
	else 
		ped=1
	fi

	trt=$(grep -n "TotalReadoutTime" $dwi_json | sed 's/^.\{24\}//' | sed 's/.$//')
	arr="0 $ped 0 $trt"
    echo $arr > "${dwi}/${sub}/acqparams.txt"
    echo 0 1 0 0 >> "${dwi}/${sub}/acqparams.txt"

    mrconvert "${raw}/${sub}/dwi/${sub}_dwi.nii.gz" \
    -fslgrad "${dwi}/${sub}/${sub}_dwi.bvec" \
    "${dwi}/${sub}/${sub}_dwi.bval" \
    "${dwi}/${sub}/${sub}_dwi_tmp.mif" \
    -force

    # Pad (rather than crop) a slice if the data is odd
    dim=$(fslinfo "${raw}/${sub}/dwi/${sub}_dwi.nii.gz" | awk '/^dim3/ {print $2}')

    # Test if dimension is even
	if [ $((dim%2)) -eq 0 ]; then
		echo "3rd dimension even, no need for padding"
	else
		echo "3rd dimension odd, padding..."
		mrgrid "${dwi}/${sub}/${sub}_dwi_tmp.mif" pad -axis 2 0,1 \
		"${dwi}/${sub}/${sub}_dwi_tmp.mif" \
		-force
	fi

	# MP-PCA denoising
	dwidenoise \
	"${dwi}/${sub}/${sub}_dwi_tmp.mif" \
	"${dwi}/${sub}/${sub}_dwi_dn_tmp.mif" \
	-noise "${dwi}/${sub}/${sub}_dwi_noise_tmp.nii.gz" \
	-force
	
	# Degibbs
	mrdegibbs \
	"${dwi}/${sub}/${sub}_dwi_dn_tmp.mif" \
	"${dwi}/${sub}/${sub}_dwi_dg_tmp.nii.gz" \
	-force
	
	# Square degibbs
	fslmaths \
	"${dwi}/${sub}/${sub}_dwi_dg_tmp.nii.gz" \
	-sqr \
	"${dwi}/${sub}/${sub}_dwi_dg_sqr_tmp.nii"
	
	# Square noise
	fslmaths \
	"${dwi}/${sub}/${sub}_dwi_noise_tmp.nii.gz" \
	-sqr \
	"${dwi}/${sub}/${sub}_dwi_noise_sqr_tmp.nii.gz"
		
	# Subtract sqaured noise from squared degibbs
	fslmaths \
	"${dwi}/${sub}/${sub}_dwi_dg_sqr_tmp.nii.gz" \
	-sub \
	"${dwi}/${sub}/${sub}_dwi_noise_sqr_tmp.nii.gz" \
	"${dwi}/${sub}/${sub}_dwi_noise_sub_dg_tmp.nii.gz"
	
	# Square root the subtracted image (eddy input)
	fslmaths \
	"${dwi}/${sub}/${sub}_dwi_noise_sub_dg_tmp.nii.gz" \
	-sqrt \
	"${dwi}/${sub}/${sub}_dwi.nii.gz"
	
	# Clean up directory of temporary files
	rm "${dwi}/${sub}/*tmp*"

	# Create a b0 image
	dwiextract \
		"${dwi}/${sub}/${sub}_dwi.nii.gz" - -bzero -fslgrad \
		"${dwi}/${sub}/${sub}_dwi.bvec" \
		"${dwi}/${sub}/${sub}_dwi.bval" | \
	mrmath - mean "${dwi}/${sub}/${sub}_dwi_b0.nii.gz" -axis 3

done
