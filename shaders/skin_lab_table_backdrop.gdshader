shader_type canvas_item;

uniform vec4 deep_space : source_color = vec4(0.006, 0.015, 0.035, 1.0);
uniform vec4 table_navy : source_color = vec4(0.018, 0.055, 0.090, 1.0);
uniform vec4 cyan_glow : source_color = vec4(0.10, 0.72, 0.90, 1.0);
uniform vec4 amber_glow : source_color = vec4(0.94, 0.60, 0.18, 1.0);
uniform float atmosphere = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float line_mask(float value, float width) {
	float d = abs(fract(value) - 0.5);
	return 1.0 - smoothstep(width, width + 0.012, d);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	float radial = length(p * vec2(1.0, 1.18));
	vec3 color = mix(table_navy.rgb, deep_space.rgb, smoothstep(0.12, 0.78, radial));

	float cyan_pool = exp(-9.0 * length((uv - vec2(0.31, 0.43)) * vec2(0.8, 1.0)));
	float amber_pool = exp(-13.0 * length((uv - vec2(0.70, 0.70)) * vec2(0.9, 1.1)));
	color += cyan_glow.rgb * cyan_pool * 0.11 * atmosphere;
	color += amber_glow.rgb * amber_pool * 0.055 * atmosphere;

	float grid_x = line_mask(uv.x * 28.0 + uv.y * 2.0, 0.018);
	float grid_y = line_mask(uv.y * 19.0, 0.018);
	float grid_fade = smoothstep(0.85, 0.25, radial);
	color += cyan_glow.rgb * (grid_x + grid_y) * 0.010 * grid_fade;

	vec2 star_cell = floor(uv * vec2(180.0, 110.0));
	float star = step(0.992, hash21(star_cell));
	float star_twinkle = 0.55 + 0.45 * sin(TIME * 0.7 + hash21(star_cell + 9.0) * 6.28318);
	color += vec3(0.72, 0.90, 1.0) * star * star_twinkle * 0.30;

	float top_rail = exp(-150.0 * abs(uv.y - 0.115));
	float bottom_rail = exp(-120.0 * abs(uv.y - 0.845));
	color += cyan_glow.rgb * top_rail * 0.050;
	color += amber_glow.rgb * bottom_rail * 0.030;

	float vignette = smoothstep(0.96, 0.30, radial);
	color *= mix(0.58, 1.0, vignette);
	COLOR = vec4(color, 1.0);
}
