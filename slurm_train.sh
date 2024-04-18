#!/bin/bash -l
#SBATCH --job-name=TrainCAI
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --partition=normal
#SBATCH --account=s83
#SBATCH --output=/scratch/clechart/hackathon/logs/model_training_normal_out.log
#SBATCH --error=/scratch/clechart/hackathon/logs/model_training_normal_err.log
#SBATCH --time=03:00:00
#SBATCH --no-requeue

source activate cloud-ai

srun -ul python src/train_model.py