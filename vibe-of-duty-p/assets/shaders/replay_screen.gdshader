shader_type canvas_item;
// Kill cam look, over the whole replayed view: washed-out colours with a cold tint, a slight colour split towards the
// edges, film grain, faint scanlines and darker corners, so a replay can't be taken for live play.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float split = 0.003;      // colour split at the screen edge, in UV
uniform float grain = 0.06;
uniform float desaturate = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_centre = uv - 0.5;
	vec2 offset = from_centre * split * 2.0;
	vec3 col;
	col.r = texture(screen, uv + offset).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - offset).b;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturate) * vec3(0.92, 0.98, 1.06);
	col += (hash(floor(FRAGCOORD.xy * 0.5) + fract(TIME * 13.0) * 100.0) - 0.5) * grain;
	col *= 0.94 + 0.06 * sin(FRAGCOORD.y * 2.1);
	float r = length(from_centre * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0));
	col *= 1.0 - smoothstep(0.35, 0.8, r) * 0.55;
	COLOR = vec4(col, 1.0);
}
