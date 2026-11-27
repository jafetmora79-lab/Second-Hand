shader_type spatial;
// The snow globe's glass: clear where you look straight through it, bright at the rim where you see it edge-on (fresnel), with a soft
// window-shaped highlight near the top so it reads as a polished glass sphere even against a dark background.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.88, 0.94, 1.0);
uniform float clear_alpha = 0.03;      // looking straight through
uniform float rim_alpha = 0.55;        // edge-on
uniform float rim_power = 3.0;

varying vec3 obj_n;

void vertex() {
	obj_n = normalize(VERTEX);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	// a highlight on the upper left of the sphere, in its own space so it turns with the globe like a reflection of the shop window
	float hl = smoothstep(0.86, 0.97, dot(obj_n, normalize(vec3(-0.45, 0.7, 0.55))));
	ALBEDO = mix(tint, vec3(1.0), hl);
	ALPHA = clamp(clear_alpha + rim * rim_alpha + hl * 0.55, 0.0, 0.9);
	EMISSION = vec3(1.0) * hl * 0.25 + tint * rim * 0.08;
	ROUGHNESS = 0.03;
	SPECULAR = 0.9;
}
