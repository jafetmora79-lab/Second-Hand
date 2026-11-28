shader_type spatial;
// The desk monitor's picture: the porch camera, as an old black-and-white security CRT shows it. Mostly grey with a faint green cast,
// scanlines, darker corners and a soft glow, unlit (the screen makes its own light).
// The glass is a real dome, like a 1950s picture tube: the screen mesh is subdivided and its middle bows out toward you while its
// edges stay at the bezel. Its outline has the tube's round corners and bowed sides, and a soft sheen sits on the curve of the glass.
render_mode unshaded, cull_back;

uniform sampler2D feed : source_color, filter_linear;
uniform float on = 1.0;          // 0 when nobody is at the door: a dark, faintly glowing screen
uniform float shape = 5.0;       // the tube's outline: a superellipse (2 = oval, higher = squarer), big round corners, bowed sides
uniform float bulge = 0.2;      // how much the picture itself bends with the glass
uniform float dome = 0.03;      // how far the middle of the glass stands out from its edges (metres)

void vertex() {
	vec2 p = UV * 2.0 - vec2(1.0);
	VERTEX.z += dome * (1.0 - p.x * p.x) * (1.0 - p.y * p.y);   // the tube's glass bows out in the middle
}

void fragment() {
	// the tube's outline: nothing outside it; the picture darkens into the glass's edge instead of stopping hard
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float r = pow(pow(d.x, shape) + pow(d.y, shape), 1.0 / shape);
	if (r > 1.0) {
		discard;
	}
	float rim = smoothstep(1.0, 0.82, r);
	// the picture bends with the glass
	vec2 p = UV - vec2(0.5);
	vec2 uv = vec2(0.5) + p * (1.0 - bulge * dot(p, p) * 4.0);
	vec3 c = texture(feed, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(0.9, 1.0, 0.92), 0.8);
	c *= 1.0 - 0.12 * step(0.5, fract(uv.y * 120.0));
	c *= 1.0 - 0.45 * smoothstep(0.2, 0.75, length(p * vec2(1.0, 1.2)));
	c = mix(vec3(0.03, 0.05, 0.04), c * 1.15, on);
	c = mix(vec3(0.03, 0.04, 0.035), c, rim);
	// the glass: a soft sheen up on the curve toward the top left, and a faint line of light along the dome's upper edge
	float sheen = smoothstep(0.34, 0.0, length((UV - vec2(0.3, 0.24)) * vec2(1.0, 1.4)));
	float lip = smoothstep(0.75, 0.95, r) * smoothstep(0.55, 0.2, UV.y) * (1.0 - smoothstep(0.98, 1.0, r));
	ALBEDO = c + vec3(0.85, 0.9, 0.88) * (sheen * 0.2 + lip * 0.12);
}
