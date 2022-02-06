from flask import Flask, jsonify, request
# initialize our Flask application
app= Flask(__name__)
flag = "False"
# @app.route("/name", methods=["POST"])
# def setName():
#     if request.method=='POST':
#         posted_data = request.get_json()
#         data = posted_data['data']
#         return jsonify(str("Successfully stored  " + str(data)))
# https://www.securify.nl/en/blog/android-adb-reverse-tethering-mitm-setup-revised/
# https://github.com/facebook/react-native/issues/8309
# https://medium.com/@godwinjoseph.k/adb-port-forwarding-and-reversing-d2bc71835d43
# https://stackoverflow.com/questions/56491976/adb-exe-error-cannot-bind-listener-operation-not-permitted
@app.route("/evil", methods=["GET"])
def evil():
    flag = "True"
    return flag
@app.route("/reset", methods=["GET"])
def reset():
    flag = "False"
    return flag
@app.route("/last", methods=["GET"])
def last():
    return flag
    flag = "False"
#  main thread of execution to start the server
if __name__=='__main__':
    app.run(debug=True, port=8888)