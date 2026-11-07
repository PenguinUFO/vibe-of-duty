// The northern lights: a curtain (Aurora builds the ribbons). UV.x runs along it, UV.y up. Geometry and not the sky
// shader: a sky that reads TIME re-renders its radiance every frame (sky_clouds.gdshader).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 low_color : source_color = vec3(0.16, 0.85, 0.5);
uniform vec3 high_color : source_color = vec3(0.45, 0.25, 0.8);
uniform float strength = 0.8;
uniform float seed = 0.0;
uniform float speed = 0.05;

float hash(float p) {
	return fract(sin(p * 127.1 + seed * 31.7) * 43758.5453);
}

float noise(float p) {
	float i = floor(p);
	float f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
	float t = TIME * speed;
	float x = UV.x;
	float y = UV.y;
	float rays = noise(x * 90.0 + t * 7.0) * 0.55 + noise(x * 230.0 - t * 11.0) * 0.45;
	float folds = noise(x * 14.0 - t * 3.0) * noise(x * 5.0 + t * 2.0 + 9.0) * 2.2;
	float top = 0.35 + 0.65 * noise(x * 9.0 + t * 4.0 + 3.0);    // how high the rays reach here
	float rise = smoothstep(0.0, 0.28, y) * pow(1.0 - clamp(y / top, 0.0, 1.0), 1.5);
	float ends = smoothstep(0.0, 0.1, x) * smoothstep(1.0, 0.9, x);
	vec3 color = mix(low_color, high_color, smoothstep(0.1, 0.7, y));
	ALBEDO = color * strength * rise * ends * folds * (0.35 + rays);
}
