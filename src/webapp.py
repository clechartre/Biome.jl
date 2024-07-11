from flask import Flask, render_template, request
from keras.models import load_model
from keras.preprocessing import image
from ultralytics import YOLO

# Use the model
#model.train(data="coco8.yaml", epochs=3)  # train the model
#metrics = model.val()  # evaluate model performance on the validation set
#results = model("https://ultralytics.com/images/bus.jpg")  # predict on an image
#path = model.export(format="onnx")  # export the model to ONNX format

app = Flask(__name__)

dic = {0 : 'altocumulus', 1 : 'altostratus', 2 : 'cirrocumulus', 3 : 'cirrostratus', 4 : 'cirrus', 5 : 'cumulonimbus', 6 : 'cumuls', 7 : 'mixed_clouds', 8 : 'nimbostratus', 9 : 'not_cloud', 10 : 'stratocumulus', 11 : 'stratus'}

# Load the model
model = YOLO("XXX")  # load our pretrained pretrained model

model.make_predict_function()

def predict_label(img_path):
	i = image.load_img(img_path, target_size=(100,100))
	i = image.img_to_array(i)/255.0
	i = i.reshape(1, 100,100,3)
	p = model.predict_classes(i)
	return dic[p[0]]


# routes
@app.route("/", methods=['GET', 'POST'])
def main():
	return render_template("index.html")

@app.route("/about")
def about_page():
	return "Test Version of the Cloud Image Classifier CloudAI by Leandro Gimmi, Michael Herrmann, Capucine Lechartre and Melina Abeling"

@app.route("/submit", methods = ['GET', 'POST'])
def get_output():
	if request.method == 'POST':
		img = request.files['my_image']

		img_path = "static/" + img.filename	
		img.save(img_path)

		p = predict_label(img_path)

	return render_template("index.html", prediction = p, img_path = img_path)


if __name__ =='__main__':
	#app.debug = True
	app.run(debug = True)