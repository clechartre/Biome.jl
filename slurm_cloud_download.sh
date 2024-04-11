#!/bin/bash -l
#SBATCH --job-name=ImgDownload
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --partition=normal
#SBATCH --account=s83
#SBATCH --output=/scratch/clechart/hackathon/data/img_download_out.log
#SBATCH --error=/scratch/clechart/hackathon/data/img_download_err.log
#SBATCH --time=03:00:00
#SBATCH --no-requeue

# Activate Conda environment
source activate /scratch/clechart/miniconda/envs/clouds

srun -ul python image_download.py