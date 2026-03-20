extends SceneTree

var http: HTTPRequest
var holder: Node

func _init():
	print("=== HTTP Connection Test ===")

func _initialize():
	# Create a holder node
	holder = Node.new()
	holder.name = "Holder"
	get_root().add_child(holder)

	# Create HTTPRequest
	http = HTTPRequest.new()
	http.timeout = 30.0
	holder.add_child(http)
	http.request_completed.connect(_on_response)

	# Use deferred call to wait for node to be in tree
	_send_request.call_deferred()

func _send_request():
	var body = JSON.stringify({
		"host": "192.168.0.237",
		"username": "az",
		"password": "7243",
		"ai_cli": "auto",
		"port": 22
	})

	var headers = ["Content-Type: application/json"]
	var url = "http://127.0.0.1:8000/api/v1/connect"

	print("Sending request to: ", url)
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)

	if err != OK:
		print("ERROR: Request failed with code: ", err)
		quit()
	else:
		print("Request sent, waiting for response...")

func _on_response(result, response_code, headers, body):
	print("Response received!")
	print("  Result: ", result)
	print("  Code: ", response_code)

	var text = body.get_string_from_utf8()
	print("  Body: ", text)

	quit()
