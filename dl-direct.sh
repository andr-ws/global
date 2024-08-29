#! /bin/bash 


SORTING OUT CURRENTLY

# Code to perform DL-DiReCT

base
derivatives

# DL-DiReCT requirements
conda create -y -n DL_DiReCT python=3.10
source activate DL_DiReCT
cd ${HOME}
git clone https://github.com/SCAN-NRAD/DL-DiReCT.git
cd DL-DiReCT
pip install numpy && pip install -e .


# Point to the minimally pre-processed brain extracted T1w MRI here!

for DIR in ${MORPHDIR}s*
do
	SUB=${basename ${DIR}
	mkdir -p ${DLDIR}${SUB}

	dl+direct \
		--subject ${SUB} \
		--bet ${DIR}/T1p.nii.gz \ # point to biasfieldcorrected?
		${DLDIR}${SUB} \
		--model v6
done
