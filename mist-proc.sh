#! /bin/bash

# Shell script for MIST segementation using T1w and T2w images

# NEED TO SET FLAGS FOR RESAMPLING (RESAMPLE BIAS_COR) AND SITE-SPECIFIC RUNS
# WHERE SHOULD THIS INFORMATION BE STORED/OBTAINED FROM?

base=./Users/neuro-239/Desktop/HCP
rawdata=${base}/rawdata
derivatives=${base}/derivatives
mni=${global}/MNI

# Create a temporary directory to run MIST in
tmp_mist-dir=${derivatives}/tmp_mist-dir
mkdir -p ${tmp_mist-dir}

# Create file containing subject names
touch ${tmp_mist-dir}/mist_subjects

# Define shortcut output names for FSL affine and affwarp xfms.
aff="T1_2_2mm_FSL_affine.mat"
warp="T1_2_2mm_FSL_warp.nii.gz"

# Iterate over each xfm directory
for dir in ${derivatives}/data/sub-*; do
  sub=$(basename ${dir})
  
  # T1w-MNI (MNI152-2mm)
  antsRegistrationSyN.sh \
  -d 3 \
  -f ${mni}/MNI152_T1_2mm_brain.nii.gz \
  -m ${dir}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz \
  -x ${mni}/MNI152_T1_2mm_brain_mask.nii.gz,${dir}/anat/${sub}_desc-bias_cor_T1w_brain_mask.nii.gz \
  -o ${dir}/xfm/${sub}_T1w-mni_2mm_

  # Convert ANTs affine xfm to FSL
  c3d_affine_tool \
  -ref ${mni}/MNI152_T1_2mm_brain.nii.gz \
  -src ${dir}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz \
  -itk ${dir}/xfm/norm/ANTs/${sub}_T1w-mni_2mm_0GenericAffine.mat \
  -ras2fsl \
  -o ${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_affine.mat

  # Convert ANTs warp xfm to FSL
  wb_command \
  -convert-warpfield -from-itk \
  ${dir}/xfm/norm/ANTs/${sub}_T1w-mni_2mm_1Warp.nii.gz \
  -to-fnirt \
  ${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_warp.nii.gz \
  ${mni}/MNI152_T1_2mm_brain.nii.gz

  # Concatenate FSL-converted affine and warpfields
  convertwarp \
  --ref=${mni}/MNI152_T1_2mm_brain.nii.gz \
  --premat=${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_affine.mat \
  --warp1=${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_warp.nii.gz \
  --out=${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_affwarp.nii.gz

  # Create temporary participant direcs and populate files
  mkdir -p ${tmp_mist-dir}/${sub}

  # Link FSL affine and warps
  ln -s ${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_affine.mat ${tmp_mist-dir}/${sub}/${aff}
  ln -s ${dir}/xfm/norm/FSL/${sub}_T1w-mni_2mm_affwarp.nii.gz ${tmp_mist-dir}/${sub}/${warp}

  # Link bias-corrected T1w/T1w_brain images
  ln -s ${dir}/anat/${sub}_desc-bias_cor_T1w.nii.gz ${tmp_mist-dir}/${sub}/T1.nii.gz
  ln -s ${dir}/anat/${sub}_desc-bias_cor_T1w_brain.nii.gz ${tmp_mist-dir}/${sub}/T1_brain.nii.gz
    
  # Link T2w MRI co-registered to T1w
  ln -s "${dir}/anat/${sub}/${sub}_desc-bias_cor_T2w_space-T1w.nii.gz" ${tmp_mist-dir}/${sub}/T2.nii.gz
    
  # Append subject to subject list
  echo ${tmp_mist-dir}/${sub} >> ${tmp_mist-dir}/mist_subjects
done

# Have supplied the T1_brain here but unsure if this may work?
echo -e '"T1","T1","T1_brain.nii.gz",1.0\n"T2","T2","T2.nii.gz",1.0\n"alternate_affine","T1_2_2mm_FSL_affine.mat"\n"alternate_warp","T1_2_2mm_FSL_warp.nii.gz"' >> ${MISTDIR}/mist_filenames

# Execute training and fitting

# cd ${MISTDIR}
${tmp_mist-dir}/mist_1_train
${tmp_mist-dir}/mist_2_fit
# cd ${BASE}
