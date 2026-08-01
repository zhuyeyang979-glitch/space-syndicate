// Derived from Naejimer's MIT-licensed clouds.gdshader.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, unshaded;

uniform sampler2D noise_texture : hint_default_black, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(0.78, 0.86, 0.91, 1.0);
uniform vec3 sun_direction_world = vec3(0.96, -0.12, -0.18);
uniform float speed : hint_range(0.0, 0.02) = 0.0022;
uniform float threshold : hint_range(0.0, 1.5) = 0.88;
uniform float softness : hint_range(0.01, 1.0) = 0.28;
uniform float max_alpha : hint_range(0.0, 0.55) = 0.30;

varying vec3 planet_normal;

void vertex() {
	planet_normal = normalize(NORMAL);
}

void fragment() {
	vec2 drift = vec2(TIME * speed, TIME * speed * 0.37);
	float primary = texture(noise_texture, UV + drift).r;
	float detail = texture(noise_texture, UV * 1.73 - drift * 0.61).r;
	float cloud_signal = primary * 0.67 + detail * 0.43;
	float coverage = smoothstep(threshold - softness, threshold + softness, cloud_signal);
	float daylight = smoothstep(-0.08, 0.12, dot(normalize(planet_normal), normalize(-sun_direction_world)));
	ALBEDO = cloud_color.rgb * mix(0.50, 1.0, daylight);
	ROUGHNESS = 1.0;
	ALPHA = coverage * max_alpha;
}
