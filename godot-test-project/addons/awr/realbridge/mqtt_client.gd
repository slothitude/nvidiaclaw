## RealBridge - Digital twin sync with real hardware via MQTT
##
## Syncs WorldState with physical sensors/actuators for robotics.
## Provides predictive simulation ahead of real-time.
class_name RealBridge
extends RefCounted

## Emitted when sensor data is received
signal sensor_received(sensor_id: String, data: Dictionary)
## Emitted when connected to MQTT broker
signal connected()
## Emitted when disconnected
signal disconnected()
## Emitted on connection error
signal connection_error(error: String)

## MQTT configuration
var config: Dictionary = {
	"broker": "localhost",
	"port": 1883,
	"client_id": "awr_realbridge",
	"keep_alive": 60,
	"topic_prefix": "awr",
	"sensor_topic": "sensors",
	"actuator_topic": "actuators",
	"sync_interval_ms": 50  # 20Hz sync rate
}

## Connection state
var _connected: bool = false
var _last_sync_time: int = 0

## Sensor data cache
var _sensor_cache: Dictionary = {}

## WorldState reference
var _world_state: Variant = null

## CausalBus for logging
var _causal_bus: Variant = null

## Sync statistics
var _stats: Dictionary = {
	"messages_sent": 0,
	"messages_received": 0,
	"syncs": 0,
	"prediction_ahead_ms": 0
}

## Initialize with optional WorldState and CausalBus
func _init(world_state: Variant = null, causal_bus: Variant = null):
	_world_state = world_state
	_causal_bus = causal_bus

## Set the WorldState to sync
func set_world_state(world_state: Variant) -> void:
	_world_state = world_state

## Set the CausalBus for logging
func set_causal_bus(causal_bus: Variant) -> void:
	_causal_bus = causal_bus

## Connect to MQTT broker (simulation mode - no actual MQTT)
func connect_to_broker(broker: String = "", port: int = 0) -> bool:
	if not broker.is_empty():
		config.broker = broker
	if port > 0:
		config.port = port

	# In a real implementation, this would use a MQTT client
	# For now, we simulate the connection
	_connected = true
	connected.emit()

	if _causal_bus:
		_causal_bus.record("realbridge_connected", {
			"broker": config.broker,
			"port": config.port
		})

	return true

## Disconnect from broker
func close_connection() -> void:
	_connected = false
	disconnected.emit()

	if _causal_bus:
		_causal_bus.record("realbridge_disconnected", {})

## Check if connected
func is_connected_to_broker() -> bool:
	return _connected

## Publish actuator command
func publish_actuator(actuator_id: String, command: Dictionary) -> bool:
	if not _connected:
		return false

	var topic = "%s/%s/%s" % [config.topic_prefix, config.actuator_topic, actuator_id]

	# In real implementation, publish to MQTT
	# _mqtt_client.publish(topic, JSON.stringify(command))

	_stats.messages_sent += 1

	if _causal_bus:
		_causal_bus.record("actuator_command", {
			"actuator_id": actuator_id,
			"command": command,
			"topic": topic
		})

	return true

## Receive sensor data (call this when MQTT message arrives)
func on_sensor_data(sensor_id: String, data: Dictionary) -> void:
	_sensor_cache[sensor_id] = {
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}

	_stats.messages_received += 1
	sensor_received.emit(sensor_id, data)

	# Update WorldState if we have position data
	if _world_state and data.has("pos"):
		var body = _world_state.get_body(sensor_id)
		if not body.is_empty():
			body.pos.x = data.pos.x
			body.pos.y = data.pos.y
			if data.has("vel"):
				body.vel.x = data.vel.x
				body.vel.y = data.vel.y

	if _causal_bus:
		_causal_bus.record("sensor_received", {
			"sensor_id": sensor_id,
			"data": data
		})

## Get cached sensor data
func get_sensor_data(sensor_id: String) -> Dictionary:
	var cached = _sensor_cache.get(sensor_id, {})
	return cached.get("data", {})

## Get sensor data age in milliseconds
func get_sensor_age(sensor_id: String) -> int:
	var cached = _sensor_cache.get(sensor_id, {})
	if cached.is_empty():
		return -1
	return Time.get_ticks_msec() - cached.timestamp

## Sync WorldState to real world (send actuator commands)
func sync_to_world() -> Dictionary:
	if not _connected or _world_state == null:
		return {"error": "Not connected or no world state"}

	var commands: Array = []

	for body in _world_state.bodies:
		if not body.get("static", false) and body.has("target_actuator"):
			var cmd = {
				"actuator_id": body.target_actuator,
				"position": {"x": body.pos.x, "y": body.pos.y},
				"velocity": {"x": body.vel.x, "y": body.vel.y}
			}
			publish_actuator(body.target_actuator, cmd)
			commands.append(cmd)

	_stats.syncs += 1
	_last_sync_time = Time.get_ticks_msec()

	return {"commands": commands, "count": commands.size()}

## Sync from real world (update WorldState from sensors)
func sync_from_world() -> Dictionary:
	if not _connected or _world_state == null:
		return {"error": "Not connected or no world state"}

	var updates: Array = []

	for sensor_id in _sensor_cache.keys():
		var body = _world_state.get_body(sensor_id)
		if not body.is_empty():
			var data = _sensor_cache[sensor_id].data
			if data.has("pos"):
				var old_pos = {"x": body.pos.x, "y": body.pos.y}
				body.pos.x = data.pos.x
				body.pos.y = data.pos.y
				updates.append({
					"id": sensor_id,
					"old_pos": old_pos,
					"new_pos": data.pos
				})
			if data.has("vel"):
				body.vel.x = data.vel.x
				body.vel.y = data.vel.y

	return {"updates": updates, "count": updates.size()}

## Run predictive simulation ahead of real-time
func predict_ahead(sim_loop: Variant, actions: Array, ms_ahead: int) -> Dictionary:
	if _world_state == null:
		return {"error": "No world state"}

	# Calculate how many frames ahead
	var frames_ahead = int(ms_ahead / 1000.0 / sim_loop.dt)
	var original_horizon = sim_loop.horizon
	sim_loop.horizon = frames_ahead

	var result = sim_loop.search_all(actions)

	# Restore original horizon
	sim_loop.horizon = original_horizon

	_stats.prediction_ahead_ms = ms_ahead

	if _causal_bus:
		_causal_bus.record("prediction_run", {
			"ms_ahead": ms_ahead,
			"frames_ahead": frames_ahead,
			"actions_count": actions.size()
		})

	return {
		"results": result,
		"frames_simulated": frames_ahead,
		"ms_ahead": ms_ahead
	}

## Get sync statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()

## Clear sensor cache
func clear_cache() -> void:
	_sensor_cache.clear()

## Map a WorldState body to a real actuator
func map_to_actuator(body_id: String, actuator_id: String) -> void:
	if _world_state == null:
		return
	var body = _world_state.get_body(body_id)
	if not body.is_empty():
		body.target_actuator = actuator_id

## Map a sensor to a WorldState body
func map_sensor_to_body(sensor_id: String, body_id: String) -> void:
	if _world_state == null:
		return
	# Store mapping for sync_from_world
	if not _sensor_cache.has("_mappings"):
		_sensor_cache["_mappings"] = {}
	_sensor_cache["_mappings"][sensor_id] = body_id

## Create a digital twin by cloning WorldState and syncing
func create_digital_twin() -> Variant:
	if _world_state == null:
		return null

	var twin = _world_state.clone()

	if _causal_bus:
		_causal_bus.record("digital_twin_created", {
			"bodies_count": twin.bodies.size()
		})

	return twin

## Compare twin with real world
func compare_with_twin(twin: Variant) -> Dictionary:
	if _world_state == null or twin == null:
		return {"error": "No world state or twin"}

	var differences: Array = []

	for twin_body in twin.bodies:
		var real_body = _world_state.get_body(twin_body.id)
		if real_body.is_empty():
			differences.append({"id": twin_body.id, "type": "missing_in_real"})
			continue

		var pos_diff = Vector2(twin_body.pos.x, twin_body.pos.y).distance_to(
			Vector2(real_body.pos.x, real_body.pos.y)
		)
		if pos_diff > 1.0:
			differences.append({
				"id": twin_body.id,
				"type": "position_drift",
				"twin_pos": twin_body.pos,
				"real_pos": real_body.pos,
				"drift": pos_diff
			})

	return {
		"differences": differences,
		"divergence_count": differences.size()
	}
