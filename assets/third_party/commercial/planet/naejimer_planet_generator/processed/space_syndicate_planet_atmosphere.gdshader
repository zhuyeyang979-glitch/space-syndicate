// Derived from Naejimer's MIT-licensed atmosphere.gdshader.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.19, 0.58, 0.82, 1.0);
uniform float edge_alpha : hint_range(0.0, 0.24) = 0.12;
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.8;
uniform float intensity : hint_range(0.0, 2.0) = 0.68;

void fragment() {
	float fresnel = pow(clamp(1.0 - dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	ALBEDO = atmosphere_color.rgb * fresnel * intensity;
	EMISSION = ALBEDO;
	ALPHA = clamp(fresnel * edge_alpha, 0.0, edge_alpha);
}
