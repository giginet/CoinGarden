shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
// Physics and input retain the original logical canvas; presentation uses
// a consistent 320 x 225 pixel grid, including rotated coins and the HUD.
uniform float pixel_size = 4.0;

void fragment() {
	vec2 dimensions = vec2(textureSize(screen_texture, 0));
	vec2 pixel = (floor(SCREEN_UV * dimensions / pixel_size) + 0.5) * pixel_size;
	// Integer fetch avoids half-texel blending in the OpenGL screen copy.
	COLOR = texelFetch(screen_texture, ivec2(pixel), 0);
}
