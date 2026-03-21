## ViewportCapture - Captures viewport/images for VLM analysis
##
## Provides utilities for capturing Godot viewports and converting
## them to formats suitable for vision model analysis.
class_name ViewportCapture
extends RefCounted

## Capture a viewport to Image
static func capture_viewport(viewport: Viewport) -> Image:
	var image = viewport.get_texture().get_image()
	return image

## Capture a viewport and return as base64 encoded PNG
static func capture_viewport_base64(viewport: Viewport) -> String:
	var image = capture_viewport(viewport)
	return image_to_base64(image)

## Capture a specific region of a viewport
static func capture_region(viewport: Viewport, region: Rect2) -> Image:
	var full_image = capture_viewport(viewport)
	var cropped = full_image.get_region(region)
	return cropped

## Convert Image to base64 encoded PNG string
static func image_to_base64(image: Image) -> String:
	var buffer = image.save_png_to_buffer()
	return Marshalls.raw_to_base64(buffer)

## Convert Image to base64 encoded JPEG string (smaller size)
static func image_to_base64_jpeg(image: Image, quality: float = 0.8) -> String:
	var buffer = image.save_jpg_to_buffer(quality)
	return Marshalls.raw_to_base64(buffer)

## Save image to temp file and return path
static func save_to_temp(image: Image, filename: String = "viewport_capture.png") -> String:
	var path = "user://%s" % filename
	image.save_png(path)
	return path

## Get globalized path for MCP tools
static func get_global_path(resource_path: String) -> String:
	return ProjectSettings.globalize_path(resource_path)

## Capture and save to temp file, return global path
static func capture_to_temp_file(viewport: Viewport, filename: String = "perception_capture.png") -> String:
	var image = capture_viewport(viewport)
	var local_path = save_to_temp(image, filename)
	return get_global_path(local_path)

## Create a thumbnail of an image
static func create_thumbnail(image: Image, max_size: int = 256) -> Image:
	var width = image.get_width()
	var height = image.get_height()
	var scale = min(float(max_size) / width, float(max_size) / height)
	var new_width = int(width * scale)
	var new_height = int(height * scale)
	image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	return image

## Capture with specific resolution
static func capture_at_resolution(viewport: Viewport, width: int, height: int) -> Image:
	var image = capture_viewport(viewport)
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return image

## Extract dominant colors from image (simple histogram)
static func extract_dominant_colors(image: Image, num_colors: int = 5) -> Array:
	var color_counts: Dictionary = {}
	var data = image.get_data()

	# Sample every 10th pixel for speed
	for i in range(0, data.size(), 30):
		var r = data.decode_u8(i)
		var g = data.decode_u8(i + 1)
		var b = data.decode_u8(i + 2)

		# Quantize to reduce color space
		var qr = (r / 32) * 32
		var qg = (g / 32) * 32
		var qb = (b / 32) * 32
		var key = "%d_%d_%d" % [qr, qg, qb]

		if color_counts.has(key):
			color_counts[key] += 1
		else:
			color_counts[key] = 1

	# Sort by count and return top colors
	var sorted = color_counts.keys()
	sorted.sort_custom(func(a, b): return color_counts[a] > color_counts[b])

	var result: Array = []
	for i in range(min(num_colors, sorted.size())):
		var parts = sorted[i].split("_")
		result.append(Color(int(parts[0]), int(parts[1]), int(parts[2])))

	return result

## Get image dimensions
static func get_dimensions(image: Image) -> Vector2i:
	return Vector2i(image.get_width(), image.get_height())

## Check if image is mostly empty (transparent/black)
static func is_empty(image: Image, threshold: float = 0.1) -> bool:
	var data = image.get_data()
	var non_empty = 0
	var total = data.size() / 4  # RGBA

	for i in range(0, data.size(), 4):
		var r = data.decode_u8(i)
		var g = data.decode_u8(i + 1)
		var b = data.decode_u8(i + 2)
		var a = data.decode_u8(i + 3)

		if a > 10 and (r > 10 or g > 10 or b > 10):
			non_empty += 1

	return float(non_empty) / total < threshold
