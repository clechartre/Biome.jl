import os
from ultralytics import YOLO

def main():

    # mlflow.set_experiment(experiment_name="cloud-ai")

    # mlflow.start_run(run_name="getting-started")


    # Load a model
    model = YOLO('yolov8n-cls.pt')  # load a pretrained model (recommended for training)

    # Train the model
    results = model.train(
        model = "yolov8n-cls.pt",
        data='/scratch/clechart/hackathon/data/', 
        # resume = True,
        device = 1,
        workers = 8,
        name = "testestest",
        epochs=100,
        project="/scratch/clechart/hackathon/runs",
        imgsz = 640,
        seed = 42,
        lr0 = 0.01, # Initial learning rate Adjusting this value is crucial for the optimization process, influencing how rapidly model weights are updated.
        lrf = 0.01 # Final learning rate as a fraction of lr0
    )

    print(results)

    # if not os.path.exists("outputs"):
    #     os.makedirs("outputs") 

    # with open("outputs/test.txt", "w") as f:
    #     f.write("hello world!")

    # mlflow.log_artifacts("outputs")

    # mlflow.end_run()

if __name__ == "__main__":
    main()