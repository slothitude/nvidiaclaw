// sky_with_clouds.gdshader - Procedural sky with animated clouds and birds
// Part of Fantasy Town World-Breaking Demo
//
// Features:
// - Animated procedural clouds
// - Flying birds (procedural)
// - Dynamic sun/moon
// - Atmospheric scattering

shader_type sky;

// Cloud settings
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.05;
uniform float cloud_scale : hint_range(0.1, 10.0) = 2.0;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sky_color_top : source_color = vec4(0.4, 0.6, 0.9, 1.0);
uniform vec4 sky_color_bottom : source_color = vec4(0.7, 0.85, 1.0, 1.0);

// Sun settings
uniform float sun_angle : hint_range(0.0, 6.28) = 0.5;
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float sun_size : hint_range(0.01, 0.2) = 0.05;

// Bird settings
uniform float bird_speed : hint_range(0.0, 5.0) = 1.0;
uniform int bird_count : hint_range(0, 20) = 5;

// Time
uniform float time = 0.0;

// Noise functions for clouds
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.0;
	}

	return value;
}

// Bird shape
float bird_shape(vec2 uv, vec2 bird_pos, float wing_phase) {
	vec2 p = uv - bird_pos;
	p.x = abs(p.x);

	// Wing flap
	float wing = sin(wing_phase) * 0.3;
	p.y += p.x * wing;

	// Simple bird shape (V)
	float body = smoothstep(0.02, 0.0, length(p * vec2(1.0, 2.0)));
	float wing_shape = smoothstep(0.015, 0.0, abs(p.y - p.x * 0.5) - 0.005) * step(0.0, p.x);

	return max(body, wing_shape);
}

void sky() {
	// Get ray direction
	vec3 dir = SKY_COORDS_TO_DIRECTION(SKY_COORDS);

	// Sky gradient
	float gradient = smoothstep(-0.2, 0.8, dir.y);
	vec3 sky_col = mix(sky_color_bottom.rgb, sky_color_top.rgb, gradient);

	// Sun
	vec3 sun_dir = vec3(cos(sun_angle), sin(sun_angle), 0.0);
	float sun_dot = dot(dir, sun_dir);
	float sun_disc = smoothstep(sun_size, sun_size * 0.8, acos(max(sun_dot, 0.0)));
	sky_col += sun_color.rgb * sun_disc * 2.0;

	// Sun glow
	float sun_glow = pow(max(sun_dot, 0.0), 8.0) * 0.3;
	sky_col += sun_color.rgb * sun_glow;

	// Clouds (only in upper hemisphere)
	if (dir.y > 0.0) {
		// Project direction to 2D for cloud sampling
		vec2 cloud_uv = dir.xz / (dir.y + 0.3) * cloud_scale;
		cloud_uv += time * cloud_speed;

		// Multi-octave cloud noise
		float cloud = fbm(cloud_uv);
		cloud = smoothstep(1.0 - cloud_density, 1.0, cloud);

		// Cloud lighting (brighter on top)
		float cloud_light = 0.5 + 0.5 * dir.y;
		vec3 cloud_col = cloud_color.rgb * (0.8 + cloud_light * 0.4);

		// Blend clouds with sky
		sky_col = mix(sky_col, cloud_col, cloud * 0.8);
	}

	// Birds (only in upper hemisphere)
	if (dir.y > 0.1 && bird_count > 0) {
		vec2 uv = dir.xz / dir.y;

		for (int i = 0; i < bird_count; i++) {
			float fi = float(i);
			// Each bird has unique position and phase
			vec2 bird_pos;
			bird_pos.x = sin(time * bird_speed * 0.3 + fi * 1.7) * 0.5;
			bird_pos.y = cos(time * bird_speed * 0.2 + fi * 2.3) * 0.3 + 0.2 * sin(time * 0.5 + fi);

			// Wing flapping
			float wing_phase = time * 8.0 + fi * 3.0;

			float bird = bird_shape(uv, bird_pos, wing_phase);
			sky_col = mix(sky_col, vec3(0.1, 0.1, 0.15), bird);
		}
	}

	COLOR = vec4(sky_col, 1.0);
}
