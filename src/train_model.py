import os
import sys
from ultralytics import YOLO

def main(gpu_id):
    model = YOLO('yolov8n-cls.pt')
    results = model.train(
        data='/users/clechart/cloudai/data/', 
        device="cpu",  # Use the passed GPU ID
        workers=1,
        name="run_cpu_3_with_MCH",
        epochs=20,
        project="/users/clechart/cloudai/run",
        imgsz=640,
        seed=42,
        lr0=0.01, 
        lrf=0.01
    )

if __name__ == "__main__":
    gpu_id = sys.argv[1]  # Expects a single GPU ID, not a list
    main(gpu_id)

