// Rivers and lakes: two scrolling ripple normal maps, a fresnel tint towards
// the sky colour at grazing angles, and a glossy surface to catch the sun.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.12, 0.2, 0.22);
uniform vec3 sky_color : source_color = vec3(0.55, 0.65, 0.72);
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float ripple_scale = 0.025;
uniform float ripple_speed = 0.015;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_position.xz * ripple_scale;
	vec3 a = texture(ripples, uv + TIME * ripple_speed * vec2(1.0, 0.6)).rgb;
	vec3 b = texture(ripples, uv * 1.7 - TIME * ripple_speed * vec2(0.5, 1.0)).rgb;
	NORMAL_MAP = normalize(mix(a, b, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color, sky_color, fresnel * 0.8);
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
}
