// Readability rim for players in the darker PSX mood (Mood): a second pass over the body that adds a faint warm
// glow on the edges facing away from the camera, so a silhouette never sinks into shadow or fog. Unaffected by
// fog and a bit stronger with distance - where the fog would otherwise swallow a far enemy. Added on top of the
// body's own shading (blend_add), it never darkens anything.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform vec3 rim_color : source_color = vec3(0.95, 0.72, 0.6);
uniform float strength = 0.6;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float far = clamp((length(VERTEX) - 4.0) / 30.0, 0.0, 1.0);
	ALBEDO = rim_color * edge * strength * (0.5 + 0.7 * far);
}
