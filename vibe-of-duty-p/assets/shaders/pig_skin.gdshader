// The pig's skin on every body part (Mannequin._material): the guns' coarse pixelated noise (weapon_skin.gdshader)
// over the part's colour (tint), mapped in the part's own space, and patches of dirt (none on the eyes). A mesh with
// vertex colours multiplies them in (sRGB; alpha - how much dirt it takes); one without reads white.
shader_type spatial;

uniform sampler2D grain : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_noise : filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);  // the part's colour
uniform float gain = 1.0;                  // 1 / the grain's mean: the skin keeps its colour on average
uniform float tiles_per_metre = 8.0;
uniform float dirt_tiles_per_metre = 3.0;
uniform vec3 dirt_color : source_color = vec3(0.25, 0.18, 0.12);
uniform float dirt_amount = 0.55;
uniform float roughness_value = 0.9;
uniform float specular_value = 0.3;

varying vec3 part_pos;
varying vec3 part_normal;

float triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).r * w.x + texture(tex, p.zx).r * w.y + texture(tex, p.xy).r * w.z;
}

void vertex() {
	part_pos = VERTEX;
	part_normal = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(normalize(part_normal)), vec3(4.0));
	w /= w.x + w.y + w.z;
	float g = triplanar(grain, part_pos * tiles_per_metre, w) * gain;
	float d = triplanar(dirt_noise, part_pos * dirt_tiles_per_metre + vec3(0.37), w);
	float patch = smoothstep(0.55, 0.62, d) * COLOR.a * dirt_amount;
	vec3 base = pow(COLOR.rgb, vec3(2.2)) * tint;
	ALBEDO = mix(base, dirt_color, patch) * g;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
}
