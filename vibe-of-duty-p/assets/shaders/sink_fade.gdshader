shader_type spatial;
// Far scenery sinking into the sea of clouds (SkyScenery.sink): opaque above fade_top, gone below fade_bottom. The sea
// is painted on the sky, so a body that just ended somewhere down there would show its end against it.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform vec4 color : source_color = vec4(0.18, 0.18, 0.19, 1.0);
uniform float fade_top = -60.0;
uniform float fade_bottom = -240.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
	ALPHA = clamp((world_y - fade_bottom) / (fade_top - fade_bottom), 0.0, 1.0);
}
