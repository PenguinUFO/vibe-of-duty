// Daytime sky with procedural cumulus clouds: zenith-to-horizon gradient, sun disk and glow from the scene's first
// directional light, and a cloud layer projected on a flat plane above the camera (fbm value noise), lit from the sun
// side and darker underneath, thinning out towards the horizon.
//
// Static on purpose: a sky shader that reads TIME makes Godot re-render the sky radiance every frame, which costs too
// much on integrated graphics. To move the clouds, change `cloud_offset` (each change re-renders the radiance once).
shader_type sky;
render_mode use_debanding;

group_uniforms sky;
uniform vec3 zenith_color : source_color = vec3(0.24, 0.47, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.80, 0.87);
uniform vec3 ground_color : source_color = vec3(0.60, 0.63, 0.67);
uniform float horizon_curve : hint_range(0.01, 1.0) = 0.35;   // lower = thinner bright band at the horizon

group_uniforms sun;
uniform float sun_size : hint_range(0.1, 5.0) = 1.2;          // degrees
uniform float sun_glow : hint_range(0.0, 2.0) = 0.6;
uniform float sun_glow_size : hint_range(1.0, 64.0) = 10.0;   // higher = tighter glow

group_uniforms clouds;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;    // share of the sky covered
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.09;  // width of the cloud edges
uniform float cloud_scale : hint_range(0.05, 4.0) = 1.1;      // smaller = bigger clouds
uniform float cloud_detail : hint_range(0.0, 1.0) = 0.8;      // weight of the small octaves (fluffy edges)
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.52, 0.58, 0.68);
uniform float cloud_shading : hint_range(0.0, 20.0) = 9.0;    // contrast between the sun side and the far side
uniform float cloud_thickness_dark : hint_range(0.0, 1.0) = 0.35;  // how much darker the thick cores are
uniform float cloud_horizon_fade : hint_range(0.01, 0.5) = 0.18;
uniform vec2 cloud_offset = vec2(0.0);

// A sea of clouds below the horizon (maps above the clouds: plane, tower). Off at sea_coverage 0. The far sea is
// sky, not geometry: it costs nothing and never ends; SkyScenery scrolls sea_offset when the map "flies".
group_uniforms sea;
uniform float sea_coverage : hint_range(0.0, 1.0) = 0.0;
uniform float sea_scale : hint_range(0.05, 4.0) = 0.6;      // smaller = bigger clouds
uniform vec3 sea_light : source_color = vec3(0.9, 0.9, 0.88);
uniform vec3 sea_shadow : source_color = vec3(0.45, 0.5, 0.58);
uniform vec2 sea_offset = vec2(0.0);
uniform float sea_horizon_fade : hint_range(0.01, 0.5) = 0.08;


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 6 octaves; all but the first two are scaled by cloud_detail.
float fbm(vec2 p) {
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < 6; i++) {
		float w = i < 2 ? amp : amp * cloud_detail;
		sum += value_noise(p) * w;
		norm += w;
		p = turn * p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return sum / norm;
}

float cloud_density(float n) {
	return smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
}


void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;

	// Base gradient.
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, zenith_color, pow(up, horizon_curve));
	} else {
		col = mix(horizon_color, ground_color, clamp(-up * 6.0, 0.0, 1.0));
	}

	// Sun.
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.5, 0.6, -0.6));
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(1.0);
	float to_sun = max(dot(dir, sun_dir), 0.0);
	float disk = smoothstep(cos(radians(sun_size)), cos(radians(sun_size * 0.7)), to_sun);
	vec3 glow = sun_col * pow(to_sun, sun_glow_size) * sun_glow * 0.5;
	col += glow;

	// Clouds on a plane above the camera: the flatter the view ray, the farther away the clouds it sees.
	float cover = 0.0;
	if (up > 0.0) {
		vec2 uv = dir.xz / (up + 0.08) * cloud_scale + cloud_offset;
		// Slight domain warp: rounder, billowy shapes instead of streaks.
		uv += vec2(value_noise(uv * 0.7 + 3.1), value_noise(uv * 0.7 - 5.7)) * 0.6;
		float n = fbm(uv);
		cover = cloud_density(n);
		if (cover > 0.001) {
			// Where the cloud thins out towards the sun it is lit; where it gets denser it is in its own shadow.
			vec2 toward_sun = normalize(sun_dir.xz + vec2(0.0001)) * 0.06;
			float n_sun = fbm(uv + toward_sun);
			float lit = clamp(0.6 + (n - n_sun) * cloud_shading, 0.0, 1.0);
			float core = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.3, n);
			vec3 cloud_col = mix(cloud_shadow, cloud_light * (0.75 + 0.25 * sun_col), lit);
			cloud_col *= 1.0 - core * cloud_thickness_dark;
			// Bright rims when looking towards the sun.
			cloud_col += sun_col * pow(to_sun, 8.0) * (1.0 - cover) * 0.35;
			cover *= smoothstep(0.0, cloud_horizon_fade, up);  // far clouds melt into the haze
			col = mix(col, cloud_col, cover);
		}
	}
	col += sun_col * disk * (1.0 - cover) * 4.0;  // clouds cover the sun

	// The sea of clouds: the same noise on a plane below, gaps showing ground_color (the depth under it).
	if (up < 0.0 && sea_coverage > 0.0) {
		vec2 uv = dir.xz / (-up + 0.03) * sea_scale + sea_offset;
		uv += vec2(value_noise(uv * 0.7 + 3.1), value_noise(uv * 0.7 - 5.7)) * 0.6;
		float n = fbm(uv);
		float sea = smoothstep(1.0 - sea_coverage, 1.0 - sea_coverage + 0.12, n);
		vec2 toward_sun = normalize(sun_dir.xz + vec2(0.0001)) * 0.06;
		float lit = clamp(0.55 + (n - fbm(uv + toward_sun)) * cloud_shading, 0.0, 1.0);
		vec3 sea_col = mix(sea_shadow, sea_light * (0.6 + 0.4 * sun_col), lit);
		vec3 below = mix(ground_color, sea_col, sea);
		col = mix(horizon_color, below, smoothstep(0.0, sea_horizon_fade, -up));  // the far sea melts into the haze
	}

	COLOR = col;
}
