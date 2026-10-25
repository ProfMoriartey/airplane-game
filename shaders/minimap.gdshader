// The minimap's ground: a circular window onto the map texture, turned so the
// player's heading points up, fading out at the rim.
shader_type canvas_item;

uniform sampler2D map_texture : filter_linear;
// The player's position on the map texture (0..1).
uniform vec2 center_uv = vec2(0.5);
// Which way the player faces, in radians clockwise from north.
uniform float heading = 0.0;
// How much of the texture the minimap's radius covers.
uniform float zoom = 0.25;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float distance = length(point);
	float c = cos(heading);
	float s = sin(heading);
	vec2 turned = vec2(c * point.x - s * point.y, s * point.x + c * point.y);
	vec3 ground = texture(map_texture, center_uv + turned * zoom).rgb;
	float inside = 1.0 - smoothstep(0.97, 1.0, distance);
	COLOR = vec4(ground * 0.8, 0.82 * inside);
}
