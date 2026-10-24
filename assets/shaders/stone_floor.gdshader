shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 stone_color_1 : source_color = vec4(0.15, 0.16, 0.19, 1.0);
uniform vec4 stone_color_2 : source_color = vec4(0.09, 0.10, 0.13, 1.0);
uniform vec4 grout_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform vec4 rune_color : source_color = vec4(0.25, 0.55, 0.85, 1.0);

uniform float tile_scale = 0.5;
uniform float grout_width : hint_range(0.01, 0.2) = 0.05;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.88;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	// Reconstruct world-space horizontal coordinates
	vec2 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 pos = world_pos * tile_scale;
	
	// Tile grid and fractional position
	vec2 id = floor(pos);
	vec2 f = fract(pos);
	
	// Distance to slab border (grout / mortar lines)
	vec2 dist_to_edge = min(f, 1.0 - f);
	float edge = min(dist_to_edge.x, dist_to_edge.y);
	float grout = smoothstep(0.0, grout_width, edge);
	
	// Random shade variation per stone slab
	float h = hash(id);
	vec3 slab_color = mix(stone_color_1.rgb, stone_color_2.rgb, h);
	
	// Subtle stone noise
	float micro = hash(pos * 6.0) * 0.06 - 0.03;
	slab_color += vec3(micro);
	
	// Combine stone and grout
	vec3 final_color = mix(grout_color.rgb, slab_color, grout);
	
	// Bastion central circle markings
	float dist_center = length(world_pos);
	float ring1 = smoothstep(0.12, 0.0, abs(dist_center - 4.5));
	float ring2 = smoothstep(0.12, 0.0, abs(dist_center - 9.0));
	float center_ring = max(ring1, ring2);
	
	final_color = mix(final_color, rune_color.rgb * 0.45, center_ring * 0.55);
	
	ALBEDO = final_color;
	ROUGHNESS = mix(0.96, roughness_val, grout);
	METALLIC = 0.04;
}
