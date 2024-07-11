
import os
import sys
from ultralytics import YOLO

def main():
    # Load a model
    model = YOLO('/users/clechart/BIOME4Py/run/run_cpu_3_with_MCH6/weights/best.pt')  # pretrained YOLOv8n model

    # Run batched inference on a list of images
    results = model(['/users/clechart/BIOME4Py/data/eval/cirrus/Kaeslin_0068.jpg'], device = "cpu")  # return a list of Results objects

    # Process results list
    for result in results:
        probs = result.probs  # Probs object for classification outputs
        print(probs)
        result.show()  # display to screen
        result.save(filename='result_test_cirrus.jpg')  # save to disk


if __name__ == "__main__":
    main()