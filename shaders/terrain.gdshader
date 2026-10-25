// Ground: the per-vertex field colours, broken up with world-space noise so
// that fields don't look flat up close or repetitive from high up.
shader_type spatial;

uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.06;
uniform float macro_scale = 0.0012;

varying vec3 world_position;

vec3 srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(0.04045, color));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine = texture(detail_noise, world_position.xz * detail_scale).r;
	float finer = texture(detail_noise, world_position.xz * detail_scale * 4.0).r;
	float macro = texture(macro_noise, world_position.xz * macro_scale).r;
	vec3 base = srgb_to_linear(COLOR.rgb);
	ALBEDO = base * (0.78 + 0.28 * fine + 0.12 * finer) * (0.88 + 0.24 * macro);
	ROUGHNESS = 1.0;
}
