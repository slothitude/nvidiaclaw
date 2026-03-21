// grass_wind.gdshader - Wind-animated grass for Fantasy Town
// Part of Fantasy Town World-Breaking Demo
//
// Features:
// - Wind animation
// - Color variation
// - Height-based bending
// - Player interaction (optional)

shader_type spatial;
render_mode cull_disabled, depth_predraw_alpha;

// Grass colors
uniform vec4 base_color : source_color = vec4(0.2, 0.5, 0.15, 1.0);
uniform vec4 tip_color : source_color = vec4(0.4, 0.7, 0.2, 1.0);
uniform vec4 dry_color : source_color = vec4(0.6, 0.55, 0.3, 1.0);

// Wind settings
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.3;

// Grass settings
uniform float height_variation : hint_range(0.0, 1.0) = 0.3;
uniform float color_variation : hint_range(0.0, 1.0) = 0.2;

// Time
uniform float time = 0.0;

varying float v_height;
varying vec3 v_normal;
varying vec2 v_uv;

// Simple noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_uv = UV;
	v_height = VERTEX.y;
	v_normal = NORMAL;

	// Wind displacement based on height
	float wind_noise = noise(VERTEX.xz * 0.5 + time * wind_speed * 0.3);
	float wind = sin(time * wind_speed + VERTEX.x * 0.5 + wind_noise * 6.28) * wind_strength;

	// Add turbulence
	float turb = noise(VERTEX.xz * 2.0 + time * wind_speed * 0.5) * wind_turbulence;
	wind += turb;

	// Apply wind to vertex (more effect at tips)
	VERTEX.x += wind * v_height * 0.3;
	VERTEX.z += wind * v_height * 0.15 * cos(time * wind_speed * 0.7);

	// Height variation
	float h_var = noise(VERTEX.xz * 0.3) * height_variation;
	VERTEX.y *= (1.0 - h_var * 0.3);
}

void fragment() {
	// Height-based color gradient
	float h = clamp(v_height / 1.0, 0.0, 1.0);
	vec3 col = mix(base_color.rgb, tip_color.rgb, h);

	// Add dry/worn patches
	float dry_mix = noise(v_uv * 10.0 + VERTEX.xz * 0.2) * color_variation;
	col = mix(col, dry_color.rgb, dry_mix * 0.5);

	// Add ambient occlusion at base
	float ao = smoothstep(0.0, 0.3, h);
	col *= 0.7 + ao * 0.3;

	// Simple lighting
	vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
	float ndotl = max(dot(normalize(v_normal), light_dir), 0.0);
	col *= 0.5 + ndotl * 0.5;

	// Slight translucency at tips
	float alpha = 0.9 + h * 0.1;

	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}
