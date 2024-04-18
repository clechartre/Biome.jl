from ultralytics import YOLO

# Load a model
model = YOLO('yolov8n-cls.pt')  # load a pretrained model (recommended for training)

# Train the model
results = model.train(data='/scratch/clechart/hackathon/data/train', epochs=100, imgsz=640)