#!/bin/bash -l
#SBATCH --job-name=TrainCAI
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:4
#SBATCH --exclusive 
#SBATCH --partition=normal
#SBATCH --account=s83
#SBATCH --output=/users/clechart/cloudai/logs/model_training_cpu3_out.log
#SBATCH --error=/users/clechart/cloudai/logs/model_training_cpu3_err.log
#SBATCH --time=24:00:00
#SBATCH --no-requeue

ulimit -c 0
export OMP_NUM_THREADS=16
export CUDA_LAUNCH_BLOCKING=1
export CRAY_CUDA_MPS=1
export TORCH_USE_CUDA_DSA=1


module load cuda
nvidia-smi
source activate cloudai

# Get only the first GPU index in the list
GPU_ID=$(echo $CUDA_VISIBLE_DEVICES | cut -d',' -f1)
echo "Using GPU ID: $GPU_ID"

# Running the script and passing the GPU ID
srun -ul python src/train_model.py $GPU_ID
