#!/bin/bash -l
#SBATCH --job-name=TrainCAI
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --partition=normal
#SBATCH --account=s83
#SBATCH --output=/scratch/clechart/hackathon/logs/model_training_out.log
#SBATCH --error=/scratch/clechart/hackathon/logs/model_training_err.log
#SBATCH --time=03:00:00
#SBATCH --no-requeue


# Activate Conda environment
source activate /scratch/clechart/miniconda/envs/cloud-ai

srun -ul process_images.sh