shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(604.0, 604.0);
uniform float globe_radius = 300.0;
uniform vec3 camera_east = vec3(0.0, 0.0, -1.0);
uniform vec3 camera_north = vec3(0.0, 1.0, 0.0);
uniform vec3 camera_forward = vec3(-1.0, 0.0, 0.0);
uniform vec3 sun_direction = vec3(0.993, 0.119, 0.0);
uniform vec3 presentation_seed_vector = vec3(0.13, -0.37, 0.61);
uniform float globe_blend : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 pixel = UV * surface_size;
	vec2 q = (pixel - surface_size * 0.5) / max(globe_radius, 1.0);
	q.y = -q.y;
	float radial_sq = dot(q, q);
	if (radial_sq > 1.0 || globe_blend < 0.015) {
		discard;
	}

	float z = sqrt(max(0.0, 1.0 - radial_sq));
	vec3 world_n = camera_east * q.x + camera_north * q.y + camera_forward * z;

	vec3 terrain_p = world_n + presentation_seed_vector * 0.41;
	float terrain_broad = terrain_p.x * terrain_p.y * 1.37
		+ terrain_p.y * terrain_p.z * 1.11
		+ terrain_p.z * terrain_p.x * 1.53;
	float terrain_ridge = (terrain_p.x * terrain_p.x - terrain_p.y * terrain_p.y) * 0.71
		+ (terrain_p.z * terrain_p.z - terrain_p.x * terrain_p.x) * 0.49;
	float terrain_fold = abs(terrain_p.x * terrain_p.y * terrain_p.z * 3.2 + terrain_broad * 0.38);
	float terrain = terrain_broad * 0.48 + terrain_ridge * 0.34 + (0.42 - terrain_fold) * 0.36;

	vec3 detail_p = world_n.yzx * 1.83 + presentation_seed_vector.zxy * 0.57;
	float detail = detail_p.x * detail_p.y * 0.91
		+ detail_p.y * detail_p.z * 0.63
		- detail_p.z * detail_p.x * 0.78;
	detail = clamp(detail, -1.0, 1.0);

	float continents = smoothstep(-0.12, 0.20, terrain + detail * 0.18);
	float highlands = smoothstep(0.24, 0.66, terrain + detail * 0.27);
	vec3 ocean = mix(vec3(0.018, 0.080, 0.145), vec3(0.035, 0.205, 0.305), detail * 0.5 + 0.5);
	vec3 land = mix(vec3(0.055, 0.245, 0.190), vec3(0.215, 0.390, 0.245), highlands);
	vec3 albedo = mix(ocean, land, continents);

	float light_dot = dot(world_n, sun_direction);
	float daylight = smoothstep(-0.10, 0.12, light_dot);
	float diffuse = 0.24 + max(light_dot, 0.0) * 0.92;
	vec3 night_color = albedo * vec3(0.12, 0.20, 0.31);
	vec3 day_color = albedo * diffuse;
	float city_glow = smoothstep(0.58, 0.88, detail) * (1.0 - daylight) * continents;
	vec3 color = mix(night_color, day_color, daylight);
	color += vec3(0.90, 0.56, 0.18) * city_glow * 0.20;

	float cloud_field = abs(detail * 0.72 + terrain * 0.31 + world_n.y * 0.11);
	float clouds = smoothstep(0.52, 0.76, cloud_field);
	color = mix(color, vec3(0.70, 0.84, 0.88) * (0.42 + daylight * 0.42), clouds * 0.14);
	float rim_base = 1.0 - z;
	float rim_sq = rim_base * rim_base;
	float rim = rim_sq * rim_sq;
	color += vec3(0.11, 0.48, 0.73) * rim * (0.48 + globe_blend * 0.34);
	color *= mix(0.88, 1.0, globe_blend);
	COLOR = vec4(color, 1.0);
}