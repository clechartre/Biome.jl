#!/bin/bash -l
#SBATCH --job-name=TrainCAI
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --partition=normal
#SBATCH --account=s83
#SBATCH --output=/users/clechart/cloudai/logs/model_training_normal_out.log
#SBATCH --error=/users/clechart/cloudai/logs/model_training_normal_err.log
#SBATCH --time=03:00:00
#SBATCH --no-requeue

ulimit -c 0
export OMP_NUM_THREADS=16

source activate cloudai

srun -ul python src/train_model.py