extends SceneTree

var http: HTTPRequest
var holder: Node

func _init():
	print("=== Connection Debug Test ===")

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
	print("[DEBUG] Sending request...")

	var body = JSON.stringify({
		"host": "192.168.0.237",
		"username": "az",
		"password": "7243",
		"ai_cli": "goose",
		"port": 22
	})

	var headers = ["Content-Type: application/json"]
	var url = "http://127.0.0.1:8000/api/v1/connect"

	print("[DEBUG] URL: ", url)
	print("[DEBUG] Body: ", body)
	print("[DEBUG] HTTP is inside tree: ", http.is_inside_tree())

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	print("[DEBUG] Request error code: ", err)

	if err != OK:
		print("[DEBUG] FAILED to send request!")
		quit()

func _on_response(result, response_code, headers, body):
	print("[DEBUG] Response received!")
	print("[DEBUG] Result: ", result)
	print("[DEBUG] HTTP Code: ", response_code)

	var text = body.get_string_from_utf8()
	print("[DEBUG] Body: ", text)

	quit()
