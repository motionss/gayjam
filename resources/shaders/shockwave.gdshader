shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec2 global_position;
uniform vec2 screen_size;
//uniform vec2 center;
uniform float force;
uniform float size;
uniform float thickness;

void fragment() {
	// Correctly normalize global_position to UV space [0, 1]
    vec2 center = (global_position + (screen_size * .5)) / screen_size;

    // Calculate aspect ratio
	float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;

	// Scale both the UVs and the center point symmetrically from the screen's center
    // This is the core fix for the circular shape.
	vec2 scaledUV = (SCREEN_UV - vec2(0.5, 0.5)) / vec2(ratio, 1.0) + vec2(0.5, 0.5);
	vec2 scaledCenter = (center - vec2(0.5, 0.5)) / vec2(ratio, 1.0) + vec2(0.5, 0.5);

    // This is an alternative to the above, which may be easier to read
    // vec2 scaledUV = (SCREEN_UV * vec2(1.0, ratio)) / ratio;
    // vec2 scaledCenter = (center * vec2(1.0, ratio)) / ratio;

    // Create the ring mask
	float mask = (1.0 - smoothstep(size - .1, size, length(scaledUV - scaledCenter))) *
			smoothstep(size - thickness - .1, size - thickness, length(scaledUV - scaledCenter));

    // Calculate the displacement vector
	vec2 disp = normalize(scaledUV - scaledCenter) * force * mask;

    // Sample the screen texture with the displaced UV coordinates
	COLOR = texture(SCREEN_TEXTURE, SCREEN_UV - disp);
}