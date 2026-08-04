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
uniform sampler2D terrain_mask : filter_linear, repeat_enable;
uniform bool terrain_mask_ready = false;
uniform vec2 terrain_texel_size = vec2(0.00390625, 0.0078125);
uniform float geography_complexity : hint_range(0.0, 2.0) = 1.0;

float surface_noise(vec3 p) {
	float a = sin(dot(p, vec3(12.9898, 78.233, 37.719)));
	float b = sin(dot(p.yzx, vec3(39.346, 11.135, 83.155)) * 1.73);
	float c = sin(dot(p.zxy, vec3(73.156, 52.235, 9.151)) * 3.11);
	return a * 0.52 + b * 0.31 + c * 0.17;
}

float broad_continent_fallback(vec3 p) {
	float broad = p.x * p.y * 1.37 + p.y * p.z * 1.11 + p.z * p.x * 1.53;
	float ridge = (p.x * p.x - p.y * p.y) * 0.71 + (p.z * p.z - p.x * p.x) * 0.49;
	float fold = abs(p.x * p.y * p.z * 3.2 + broad * 0.38);
	return smoothstep(-0.12, 0.20, broad * 0.48 + ridge * 0.34 + (0.42 - fold) * 0.36);
}

vec2 world_uv(vec3 unit) {
	float lon = atan(unit.z, unit.x);
	float lat = asin(clamp(unit.y, -1.0, 1.0));
	return vec2(fract(lon / TAU), clamp(0.5 - lat / PI, 0.0, 1.0));
}

void fragment() {
	vec2 pixel = UV * surface_size;
	vec2 q = (pixel - surface_size * 0.5) / max(globe_radius, 1.0);
	q.y = -q.y;
	float radial_sq = dot(q, q);
	if (radial_sq > 1.0 || globe_blend < 0.015) {
		discard;
	}

	float z = sqrt(max(0.0, 1.0 - radial_sq));
	vec3 world_n = normalize(camera_east * q.x + camera_north * q.y + camera_forward * z);
	vec2 terrain_uv = world_uv(world_n);
	float mask_center = texture(terrain_mask, terrain_uv).r;
	float mask_left = texture(terrain_mask, terrain_uv - vec2(terrain_texel_size.x, 0.0)).r;
	float mask_right = texture(terrain_mask, terrain_uv + vec2(terrain_texel_size.x, 0.0)).r;
	float mask_up = texture(terrain_mask, terrain_uv - vec2(0.0, terrain_texel_size.y)).r;
	float mask_down = texture(terrain_mask, terrain_uv + vec2(0.0, terrain_texel_size.y)).r;
	float authoritative_land = smoothstep(0.36, 0.64, mask_center);
	float fallback_land = broad_continent_fallback(world_n + presentation_seed_vector * 0.41);
	float land_mask = terrain_mask_ready ? authoritative_land : fallback_land;
	float coast_gradient = max(max(abs(mask_center - mask_left), abs(mask_center - mask_right)), max(abs(mask_center - mask_up), abs(mask_center - mask_down)));
	float coast = terrain_mask_ready ? smoothstep(0.05, 0.42, coast_gradient) : smoothstep(0.32, 0.58, 1.0 - abs(fallback_land - 0.5) * 2.0);

	float detail_scale = mix(2.4, 5.8, geography_complexity * 0.5);
	float broad_detail = surface_noise(world_n * detail_scale + presentation_seed_vector * 2.1);
	float fine_detail = surface_noise(world_n * (detail_scale * 2.37) - presentation_seed_vector * 1.7);
	float terrain_height = broad_detail * 0.68 + fine_detail * 0.32;

	vec3 tangent = cross(vec3(0.0, 1.0, 0.0), world_n);
	if (dot(tangent, tangent) < 0.001) {
		tangent = cross(vec3(1.0, 0.0, 0.0), world_n);
	}
	tangent = normalize(tangent);
	vec3 bitangent = normalize(cross(world_n, tangent));
	float epsilon = 0.018;
	float dx = surface_noise((world_n + tangent * epsilon) * detail_scale + presentation_seed_vector * 2.1)
		- surface_noise((world_n - tangent * epsilon) * detail_scale + presentation_seed_vector * 2.1);
	float dy = surface_noise((world_n + bitangent * epsilon) * detail_scale + presentation_seed_vector * 2.1)
		- surface_noise((world_n - bitangent * epsilon) * detail_scale + presentation_seed_vector * 2.1);
	vec3 relief_normal = normalize(world_n + (tangent * dx + bitangent * dy) * land_mask * 0.22);

	float ocean_depth = clamp(0.56 - terrain_height * 0.20, 0.0, 1.0);
	vec3 deep_ocean = vec3(0.008, 0.055, 0.112);
	vec3 shelf_ocean = vec3(0.025, 0.245, 0.355);
	vec3 ocean = mix(deep_ocean, vec3(0.018, 0.125, 0.225), ocean_depth);
	ocean = mix(ocean, shelf_ocean, coast * (1.0 - land_mask) * 0.82);

	float highlands = smoothstep(0.20, 0.76, terrain_height);
	float inland = terrain_mask_ready ? clamp(1.0 - coast, 0.0, 1.0) : 1.0;
	vec3 lowland = vec3(0.055, 0.255, 0.145);
	vec3 upland = vec3(0.285, 0.405, 0.205);
	vec3 land = mix(lowland, upland, highlands * inland);
	land = mix(vec3(0.20, 0.36, 0.20), land, inland);
	vec3 albedo = mix(ocean, land, land_mask);

	float light_dot = dot(relief_normal, normalize(sun_direction));
	float daylight = smoothstep(-0.10, 0.12, light_dot);
	float diffuse = 0.20 + max(light_dot, 0.0) * 0.96;
	vec3 night_color = albedo * vec3(0.10, 0.16, 0.28);
	vec3 day_color = albedo * diffuse;
	vec3 color = mix(night_color, day_color, daylight);

	float cloud_field = abs(surface_noise(world_n * 4.1 + presentation_seed_vector.zxy * 1.9));
	float clouds = smoothstep(0.62, 0.91, cloud_field);
	color = mix(color, vec3(0.70, 0.84, 0.88) * (0.38 + daylight * 0.44), clouds * 0.10);

	float rim_base = 1.0 - z;
	float rim = rim_base * rim_base * rim_base * rim_base;
	color += vec3(0.11, 0.48, 0.73) * rim * (0.52 + globe_blend * 0.34);
	color *= mix(0.88, 1.0, globe_blend);
	COLOR = vec4(color, 1.0);
}
