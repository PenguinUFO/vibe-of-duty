// PSX look over the finished 3D frame, at full resolution (nothing gets blurrier or blockier, enemies stay as
// readable as without it): the colours are cut down to `levels` steps per channel, like the PlayStation's 15-bit
// colour, with a 4x4 ordered (Bayer) dither in cells of `cell` screen pixels in between the steps. Smooth gradients
// (fog, sky, shading) get the console's banding and cross-hatch; edges and details are untouched.
// Drawn by Settings on a CanvasLayer below every UI layer, so menus and the HUD stay crisp.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 32.0;
uniform float cell = 2.0;
uniform float dither = 1.0;  // 0..1: how much of the step the dither spreads

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 p = ivec2(mod(floor(FRAGCOORD.xy / cell), 4.0));
	float d = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	float steps = levels - 1.0;
	c = floor(c * steps + 0.5 + d * dither) / steps;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
