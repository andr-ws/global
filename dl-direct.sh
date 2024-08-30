#! /bin/bash 

# Code to perform DL-DiReCT

# Variables 
dl_env_name="DL_DiReCT"
install_dir="${HOME}/DL-DiReCT"
repo_url="https://github.com/SCAN-NRAD/DL-DiReCT.git"
first_run="${install_dir}/.setup_done"

# Function to check if a conda environment exists
function conda_env_exists() {
	conda env list | grep -q "$1" 
} 

# Function to check if a directory exists
function dir_exists() { 
	[ -d "$1" ] 
}

# Function to install required dependencies 
function install_requirements() { 
	echo "Installing requirements..." 
	# Check if the conda environment exists 
	if ! conda_env_exists "${dl_env_name}"; then 
		echo "Creating conda environment: ${dl_env_name}" 
		conda create -y -n "${dl_env_name}" python=3.10 || { echo "Failed to create conda environment."; exit 1; }
	else 
		echo "Conda environment ${dl_env_name} already exists. Skipping creation." 
	fi

	# Activate the environment source activate "${dl_env_name}" 
	# Check if the directory already exists 
	if ! dir_exists "${install_dir}"; then 
		echo "Cloning the repository..." git clone "$REPO_URL" "${install_dir}" || { echo "Failed to clone repository."; exit 1; } 
	else 
		echo "Directory ${install_dir} already exists. Skipping clone."
	fi 

	# Mark setup as done touch "${first_run}" 
} 

# Main script
if [ ! -f "${first_run}" ]; then 
	install_requirements 
else 
	echo "Requirements already installed. Skipping setup." 
fi


base
derivatives=${base}/derivatives

# DL-DiReCT requirements
#conda create -y -n DL_DiReCT python=3.10
#source activate DL_DiReCT
#cd ${HOME}
#git clone https://github.com/SCAN-NRAD/DL-DiReCT.git
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
