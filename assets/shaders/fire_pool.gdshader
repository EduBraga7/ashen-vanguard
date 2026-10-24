shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Poça de fogo: disco com bordas irregulares e ruído animado. Usado pela FirePool.

uniform vec4 core_color : source_color = vec4(1.0, 0.8, 0.25, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.25, 0.03, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float n = value_noise(uv * 4.0 + vec2(TIME * 1.4, -TIME * 2.2)) * 0.6
			+ value_noise(uv * 8.0 - vec2(TIME * 2.0, TIME * 1.1)) * 0.4;
	float shape = dist + (n - 0.5) * 0.45;
	float body = smoothstep(0.95, 0.45, shape);
	vec3 col = mix(edge_color.rgb, core_color.rgb, smoothstep(0.85, 0.15, shape));
	ALBEDO = col * (0.7 + n * 0.8);
	ALPHA = body * fade;
}
