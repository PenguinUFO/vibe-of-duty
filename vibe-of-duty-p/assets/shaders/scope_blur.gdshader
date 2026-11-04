// The world round an optic's window, out of focus (ScopeBlur): the eye is on the window. One screen-filling quad, drawn
// first of the transparent things - smoke, the flash and the lens go over it. The gun is nearer than `sharp_within` and
// stays sharp: its pixels are skipped, and left out of the taps, or it would smear over the world along its outline.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 center = vec2(0.5);  // the window, in screen shares
uniform vec2 box;                 // a rectangular window's half sizes, of the screen height
uniform float radius = 0.1;       // a round one's; both past the box: its corners' radius
uniform float amount = 0.0;
uniform float spread = 0.01;      // of the screen height: how far the taps reach
uniform float lod = 3.0;          // the screen's mip they read
uniform float edge = 0.06;        // of the screen height: how far past the window the blur fades in
uniform float sharp_within = 2.0;  // m

const int TAPS = 4;  // each costs; the screen's mip is what blurs

float distance_at(vec2 uv, mat4 inv_projection) {
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, texture(depth, uv).r, 1.0);
	return -view.z / view.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 off_center = abs(SCREEN_UV - center) * vec2(aspect, 1.0);
	float mask = amount * smoothstep(0.0, edge, length(max(off_center - box, 0.0)) - radius);
	if (mask <= 0.0 || distance_at(SCREEN_UV, INV_PROJECTION_MATRIX) < sharp_within) {
		discard;
	}
	vec3 sum = textureLod(screen, SCREEN_UV, lod).rgb;
	float weight = 1.0;
	for (int i = 0; i < TAPS; i++) {
		float angle = TAU * (float(i) + 0.5) / float(TAPS);
		vec2 uv = SCREEN_UV + vec2(cos(angle) / aspect, sin(angle)) * spread;
		if (distance_at(uv, INV_PROJECTION_MATRIX) >= sharp_within) {
			sum += textureLod(screen, uv, lod).rgb;
			weight += 1.0;
		}
	}
	ALBEDO = sum / weight;
	ALPHA = mask;
}
