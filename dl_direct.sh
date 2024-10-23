#! /bin/bash 

# Setup variables 
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

	# Activate the environment 
 	source activate "${dl_env_name}" 
  
	# Check if the directory already exists 
	if ! dir_exists "${install_dir}"; then 
		echo "Cloning the repository..." 
  		git clone "$REPO_URL" "${install_dir}" || { echo "Failed to clone repository."; exit 1; } 
	else 
		echo "Directory ${install_dir} already exists. Skipping clone."
	fi 

	# Mark setup as done (initialises file on the first run)
 	touch "${first_run}" 
} 

# Main script
if [ ! -f "${first_run}" ]; then 
	install_requirements 
else 
	echo "Requirements already installed. Skipping setup." 
fi

# Code to execute DL-DiReCT

# Prompt the base path
read -p "Enter the base path of the dataset (e.g., ./path/2/data): " base
derivatives=${base}/derivatives

# Point to the minimally pre-processed resampled brain extracted T1w MRI here!
find "${derivatives}/data" -type d -name 'sub-*' | sort -V | while read -r dir; do
	
 	# extract subject-id and create directory
	sub=$(basename "${dir}")

	t1="${derivatives}/data/${sub}/anat/${sub}_desc-res-1mm_bfc_T1w_brain.nii.gz"
	dl_out="${derivatives}/dl_direct/${sub}"
	mkdir -p "${dl_out}"

	dl+direct \
		--subject "${sub}" \
		--bet ${t1} \
		${dl_out} \
		--model v6
done
