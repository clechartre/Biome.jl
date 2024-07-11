import torch

def check_gpu(gpu_id):
    if torch.cuda.is_available():
        print(f"CUDA is available! Using GPU: {gpu_id}")
        device = torch.device(f'cuda:{gpu_id}')
        print(torch.cuda.get_device_name(device))
    else:
        print("CUDA is not available.")

if __name__ == "__main__":
    import sys
    gpu_id = sys.argv[1]  # Expects a single GPU ID, not a list
    check_gpu(gpu_id)
