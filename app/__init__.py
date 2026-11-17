from flask import Flask

app = Flask(__name__)


@app.get("/")
def index():
    return {"message": "Hello from the Flask capstone"}


@app.get("/health")
def health():
    return {"status": "ok"}, 200
