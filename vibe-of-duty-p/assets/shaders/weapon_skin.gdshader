// Weapon surfaces (WeaponSkin): the train's coarse pixelated noise (Block), tinted by the part's colour, but mapped
// in the part's own space - the gun moves, a world mapping would crawl over it. Triplanar: the sides (x) and the top
// and bottom (y) both run the texture's u along the barrel (z), so wood grain follows the gun's length.
shader_type spatial;

uniform sampler2D grain : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.5);
uniform float gain = 1.0;            // 1 / the texture's mean: the part keeps its colour on average
uniform float metallic_value = 0.0;
uniform float roughness_value = 0.7;
uniform float tiles_per_metre = 4.0;

varying vec3 part_pos;
varying vec3 part_normal;

void vertex() {
	part_pos = VERTEX;
	part_normal = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(normalize(part_normal)), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 p = part_pos * tiles_per_metre;
	float g = texture(grain, p.zy).r * w.x + texture(grain, p.zx).r * w.y + texture(grain, p.xy).r * w.z;
	ALBEDO = tint * g * gain;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
}
