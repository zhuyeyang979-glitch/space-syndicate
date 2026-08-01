// Derived from Naejimer's MIT-licensed body.gdshader.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D noise_texture : hint_default_black, repeat_enable;
uniform vec4 ocean_deep : source_color = vec4(0.015, 0.105, 0.18, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.025, 0.24, 0.31, 1.0);
uniform vec4 lowland : source_color = vec4(0.10, 0.31, 0.24, 1.0);
uniform vec4 highland : source_color = vec4(0.32, 0.39, 0.31, 1.0);
uniform vec4 ice : source_color = vec4(0.77, 0.87, 0.89, 1.0);
uniform vec3 sun_direction_world = vec3(0.96, -0.12, -0.18);
uniform float night_brightness : hint_range(0.45, 0.55) = 0.50;
uniform float day_brightness : hint_range(1.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.5, 8.0) = 1.20;
uniform float terrain_contrast : hint_range(0.5, 2.0) = 0.94;

varying vec3 planet_normal;
varying vec3 triplanar_position;
varying vec3 triplanar_weight;

vec4 sample_triplanar(sampler2D source, vec3 weights, vec3 position) {
	vec4 sample_value = vec4(0.0);
	sample_value += texture(source, position.xy) * weights.z;
	sample_value += texture(source, position.xz) * weights.y;
	sample_value += texture(source, position.zy * vec2(-1.0, 1.0)) * weights.x;
	return sample_value;
}

void vertex() {
	planet_normal = normalize(NORMAL);
	triplanar_weight = pow(abs(NORMAL), vec3(1.35));
	triplanar_weight /= max(dot(triplanar_weight, vec3(1.0)), 0.0001);
	triplanar_position = VERTEX * noise_scale * vec3(1.0, -1.0, 1.0);
}

void fragment() {
	vec3 sampled = sample_triplanar(noise_texture, triplanar_weight, triplanar_position).rgb;
	float height_value = clamp(pow(max(max(sampled.r, sampled.g), sampled.b), terrain_contrast), 0.0, 1.0);
	vec3 terrain = ocean_deep.rgb;
	if (height_value >= 0.43) {
		terrain = ocean_shallow.rgb;
	}
	if (height_value >= 0.50) {
		terrain = lowland.rgb;
	}
	if (height_value >= 0.64) {
		terrain = highland.rgb;
	}
	if (height_value >= 0.82) {
		terrain = ice.rgb;
	}
	float sun_alignment = dot(normalize(planet_normal), normalize(-sun_direction_world));
	float daylight = smoothstep(-0.08, 0.12, sun_alignment);
	float hemisphere_brightness = mix(night_brightness, day_brightness, daylight);
	ALBEDO = terrain * hemisphere_brightness;
	ROUGHNESS = mix(0.32, 0.82, smoothstep(0.48, 0.72, height_value));
	METALLIC = 0.0;
	ALPHA = 1.0;
}
