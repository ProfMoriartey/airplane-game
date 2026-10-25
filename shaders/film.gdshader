// A subtle old-film look over the 3D view: darkened corners and a little grain.
shader_type canvas_item;

uniform float vignette_strength = 0.35;
uniform float grain_strength = 0.035;

float random(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = SCREEN_UV - 0.5;
	float shade = smoothstep(0.35, 0.85, length(centered * vec2(1.25, 1.0))) * vignette_strength;
	float grain = (random(SCREEN_UV * 731.0 + fract(TIME * 13.7)) - 0.5) * grain_strength;
	// Grain (light or dark speckles) layered over the black vignette.
	float grain_alpha = abs(grain);
	float alpha = grain_alpha + shade * (1.0 - grain_alpha);
	vec3 grain_color = vec3(step(0.0, grain));
	COLOR = vec4(grain_color * grain_alpha / max(alpha, 0.0001), alpha);
}
