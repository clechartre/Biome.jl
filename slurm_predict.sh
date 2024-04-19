#!/bin/bash -l
#SBATCH --job-name=TrainCAI
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:4
#SBATCH --exclusive 
#SBATCH --partition=normal
#SBATCH --account=s83
#SBATCH --output=/users/clechart/cloudai/logs/model_predict_cpu3_out.log
#SBATCH --error=/users/clechart/cloudai/logs/model_predict_cpu3_err.log
#SBATCH --time=24:00:00
#SBATCH --no-requeue

ulimit -c 0
export OMP_NUM_THREADS=16
export CUDA_LAUNCH_BLOCKING=1
export CRAY_CUDA_MPS=1
export TORCH_USE_CUDA_DSA=1

source activate cloudai 

srun -ul python predict.py