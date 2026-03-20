## BackendManager
## Manages the SSH AI Bridge backend process.
extends Node

## Emitted when backend status changes
signal status_changed(running: bool, message: String)

## Path to the backend directory
const BACKEND_DIR := "C:/Users/aaron/Desktop/014_nvidiaclaw/ssh-ai-bridge"

## Backend URL
const BACKEND_URL := "http://127.0.0.1:8000"

## Check interval in seconds
const CHECK_INTERVAL := 5.0

## Is backend running
var is_running: bool = false

## Check timer
var _check_timer: Timer = null

## HTTP request for checking
var _check_http: HTTPRequest = null


func _ready() -> void:
	print("[BackendManager] _ready called")

	# Create timer for periodic checks
	_check_timer = Timer.new()
	_check_timer.wait_time = CHECK_INTERVAL
	_check_timer.autostart = true
	_check_timer.timeout.connect(_check_backend_status)
	add_child(_check_timer)

	# Check initial status
	_check_backend_status()


## Check if backend is running
func _check_backend_status() -> void:
	# Clean up old HTTP request if exists
	if _check_http and is_instance_valid(_check_http):
		_check_http.queue_free()

	_check_http = HTTPRequest.new()
	_check_http.timeout = 3.0
	add_child(_check_http)

	_check_http.request_completed.connect(_on_health_check_completed)
	var err := _check_http.request(BACKEND_URL + "/api/v1/health", [], HTTPClient.METHOD_GET)

	if err != OK:
		print("[BackendManager] Failed to start health check request")
		_set_status(false, "Backend not reachable")


func _on_health_check_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[BackendManager] Health check completed - result: ", result, " response_code: ", response_code)

	var was_running := is_running

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_set_status(true, "Running")
	else:
		_set_status(false, "Stopped")


func _set_status(running: bool, message: String) -> void:
	var changed := is_running != running
	is_running = running

	if changed:
		print("[BackendManager] Status changed to: ", running, " - ", message)
		status_changed.emit(running, message)


## Start the backend
func start_backend() -> void:
	print("[BackendManager] start_backend called")

	if is_running:
		print("[BackendManager] Already running")
		status_changed.emit(true, "Already running")
		return

	status_changed.emit(false, "Starting backend...")

	# Start the backend process using OS.create_process (non-blocking)
	# Use start /B to run in background
	var args := PackedStringArray([
		"/c",
		"start",
		"/B",
		"cmd",
		"/c",
		"cd",
		BACKEND_DIR,
		"&&",
		"python",
		"-m",
		"uvicorn",
		"main:app",
		"--host",
		"127.0.0.1",
		"--port",
		"8000"
	])
	var pid := OS.create_process("cmd", args, false)

	print("[BackendManager] Started process with PID: ", pid)

	if pid == -1:
		print("[BackendManager] Failed to start backend")
		status_changed.emit(false, "Failed to start backend")
		return

	# The status will be updated by the periodic check timer
	# Just return immediately - don't block


## Stop the backend
func stop_backend() -> void:
	print("[BackendManager] stop_backend called")

	status_changed.emit(false, "Stopping backend...")

	# Kill Python processes using non-blocking create_process
	var args := PackedStringArray(["/F", "/IM", "python.exe"])
	OS.create_process("taskkill", args, false)

	# Status will be updated by periodic check


## Restart the backend
func restart_backend() -> void:
	print("[BackendManager] restart_backend called")
	status_changed.emit(false, "Restarting backend...")

	# Stop first
	var args := PackedStringArray(["/F", "/IM", "python.exe"])
	OS.create_process("taskkill", args, false)

	# Wait then start
	await get_tree().create_timer(2.0).timeout

	# Now start
	var start_args := PackedStringArray([
		"/c",
		"start",
		"/B",
		"cmd",
		"/c",
		"cd",
		BACKEND_DIR,
		"&&",
		"python",
		"-m",
		"uvicorn",
		"main:app",
		"--host",
		"127.0.0.1",
		"--port",
		"8000"
	])
	OS.create_process("cmd", start_args, false)


## Get backend status
func get_status() -> Dictionary:
	return {
		"running": is_running,
		"url": BACKEND_URL,
		"health_url": BACKEND_URL + "/api/v1/health"
	}
