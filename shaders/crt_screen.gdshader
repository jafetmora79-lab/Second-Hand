shader_type spatial;
// The desk monitor's picture: the porch camera, as an old black-and-white security CRT shows it. Mostly grey with a faint green cast,
// scanlines, darker corners and a soft glow, unlit (the screen makes its own light). The picture has the rounded corners of the
// tube's glass and bulges a little toward the middle, so it sits inside the walnut cabinet's rounded opening.
render_mode unshaded, cull_back;

uniform sampler2D feed : source_color, filter_linear;
uniform float on = 1.0;          // 0 when nobody is at the door: a dark, faintly glowing screen
uniform float shape = 5.0;       // the tube's outline: a superellipse (2 = oval, higher = squarer), big round corners, bowed sides
uniform float bulge = 0.08;      // how much the picture bows out, like a curved tube

void fragment() {
	// the tube's outline: nothing outside it; the picture darkens into the glass's edge instead of stopping hard
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float r = pow(pow(d.x, shape) + pow(d.y, shape), 1.0 / shape);
	if (r > 1.0) {
		discard;
	}
	float rim = smoothstep(1.0, 0.86, r);
	// a slight barrel bulge
	vec2 p = UV - vec2(0.5);
	vec2 uv = vec2(0.5) + p * (1.0 - bulge * dot(p, p) * 4.0);
	vec3 c = texture(feed, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(0.9, 1.0, 0.92), 0.8);
	c *= 1.0 - 0.12 * step(0.5, fract(uv.y * 120.0));
	c *= 1.0 - 0.45 * smoothstep(0.2, 0.75, length(p * vec2(1.0, 1.2)));
	c = mix(vec3(0.03, 0.05, 0.04), c * 1.15, on);
	ALBEDO = mix(vec3(0.03, 0.04, 0.035), c, rim);
}
