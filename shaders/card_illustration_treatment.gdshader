shader_type canvas_item;

uniform int tint_mode = 0;
uniform vec4 accent_color : source_color = vec4(0.25, 0.82, 0.94, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.005, 0.018, 0.045, 1.0);
uniform float authored_grade = 0.06;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 color = source.rgb;
	if (tint_mode == 1) {
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		float ink = smoothstep(0.025, 0.975, luminance);
		color = mix(shadow_color.rgb, accent_color.rgb, ink);
	} else {
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		vec3 restrained = mix(vec3(luminance), source.rgb, 0.90);
		color = mix(restrained, restrained * accent_color.rgb * 1.18, authored_grade);
	}
	COLOR = vec4(color, source.a);
}
