shader_type canvas_item;

uniform vec4 ocean_deep : source_color = vec4(0.015, 0.075, 0.15, 1.0);
uniform vec4 ocean_light : source_color = vec4(0.04, 0.46, 0.62, 1.0);
uniform vec4 land_color : source_color = vec4(0.15, 0.48, 0.36, 1.0);
uniform vec4 city_light : source_color = vec4(0.95, 0.72, 0.28, 1.0);
uniform vec4 rim_color : source_color = vec4(0.18, 0.84, 1.0, 1.0);

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

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.08;
	float radius = length(p);
	float globe = 1.0 - smoothstep(0.83, 0.86, radius);
	float atmosphere = smoothstep(1.02, 0.78, radius) - smoothstep(0.88, 0.78, radius);
	float n = noise(p * 4.2 + vec2(TIME * 0.012, 0.0));
	float continents = smoothstep(0.54, 0.66, n + p.y * 0.05) * globe;
	float light = clamp(0.28 + dot(normalize(vec3(p, sqrt(max(0.0, 1.0 - radius * radius)))), normalize(vec3(-0.45, -0.6, 0.75))) * 0.72, 0.08, 1.0);
	vec3 ocean = mix(ocean_deep.rgb, ocean_light.rgb, light);
	vec3 surface = mix(ocean, land_color.rgb * (0.62 + light * 0.65), continents);
	float grid = smoothstep(0.97, 1.0, abs(sin((atan(p.y, p.x) + TIME * 0.012) * 12.0))) * 0.06;
	float cities = step(0.985, hash(floor((p + 1.0) * 20.0))) * continents * light;
	surface += rim_color.rgb * grid + city_light.rgb * cities * 0.85;
	vec3 color = surface * globe + rim_color.rgb * atmosphere * 0.85;
	float alpha = max(globe, atmosphere * 0.78);
	COLOR = vec4(color, alpha);
}
