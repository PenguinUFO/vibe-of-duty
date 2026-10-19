shader_type canvas_item;
// Full-screen red vignette for the local player's HUD: `hurt` flashes after a hit (a short tint over the whole view
// plus dark-red edges), `low` holds the edges in while health is low (the script pulses it).

uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float low : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // round, not stretched to the screen's aspect
	float r = length(p);
	float strength = clamp(low * 0.85 + hurt, 0.0, 1.0);
	float inner = mix(0.62, 0.32, strength);  // a stronger effect closes in further
	float edge = smoothstep(inner, inner + 0.42, r);
	float a = edge * (0.25 + 0.65 * strength) * step(0.001, strength) + hurt * 0.1;
	COLOR = vec4(mix(vec3(0.5, 0.0, 0.02), vec3(0.16, 0.0, 0.0), edge), clamp(a, 0.0, 0.9));
}
