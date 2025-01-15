#!/bin/bash
#!/bin/bash
#SBATCH --job-name=bedpostx
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --mem=32GB
#SBATCH --time=06:00:00
#SBATCH --mail-type=END
#SBATCH --mail-user=luke.andrews@liverpool.ac.uk

# CODE DESCRIPTION:
# Runs bedpostX_gpu on eddy-corrected data

# Requirements
module load apps/fsl/6.0.7.9

# Code start
sb0dir=/mnt/data1/users/a9ws/synb0_ppmi

for dir in ${sb0dir}/sub-*; do
  sub=$(basename ${dir})
  mkdir ${dir}/bedpostx

  # Populate required files
  cp ${dir}/synb0/INPUTS/${sub}_dwi.bval ${dir}/bedpostx/bvals
  cp ${dir}/eddy/${sub}_dwi_edc.eddy_rotated_bvecs ${dir}/bedpostx/bvecs
  cp ${dir}/eddy/${sub}_dwi_edc.nii.gz ${dir}/bedpostx/data.nii.gz
  cp ${dir}/eddy/b0_topup_brain_mask.nii.gz ${dir}/bedpostx/nodif_brain_mask.nii.gz

  # Run bedpostX
  bedpostx_gpu ${dir}/bedpostx

  # File cleanup
  rm -r ${dir}/bedpostx
  mv ${dir}/bedpostx.bedpostX ${dir}/bedpostx

done
