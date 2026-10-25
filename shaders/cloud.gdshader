// A soft cloud puff drawn as a camera-facing quad. Lit from above, darker
// underneath, and faded out when the camera is about to fly through it.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D puff : filter_linear_mipmap;
uniform vec3 top_color : source_color = vec3(1.0);
uniform vec3 bottom_color : source_color = vec3(0.72, 0.75, 0.8);
uniform float opacity = 0.85;
uniform float near_fade = 120.0;

void vertex() {
	// Face the camera, keeping each puff's own size.
	float puff_size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * puff_size,
		INV_VIEW_MATRIX[1] * puff_size,
		INV_VIEW_MATRIX[2] * puff_size,
		MODEL_MATRIX[3]);
}

void fragment() {
	float shape = texture(puff, UV).a;
	float distance = length(VERTEX);
	ALBEDO = mix(top_color, bottom_color, UV.y) * COLOR.rgb;
	ALPHA = shape * opacity * smoothstep(near_fade * 0.25, near_fade, distance);
}
