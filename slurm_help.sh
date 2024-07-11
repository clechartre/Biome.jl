#!/bin/bash
#SBATCH --job-name=TestGPUAccess
#SBATCH --gres=gpu:1  # Request only one GPU
#SBATCH --output=test_gpu_access_output.txt
#SBATCH --error=test_gpu_access_error.txt
#SBATCH --time=10:00
#SBATCH --partition=debug

module load cuda
source activate cloudai

# Get only the first GPU index in the list
GPU_ID=$(echo $CUDA_VISIBLE_DEVICES | cut -d',' -f1)
echo "Using GPU ID: $GPU_ID"

# Running the Python script with the correct GPU ID
python test_gpu.py $GPU_ID
