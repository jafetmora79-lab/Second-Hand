shader_type spatial;
// The desk monitor's picture: the porch camera, as an old black-and-white security CRT shows it. Mostly grey with a faint green cast,
// scanlines, darker corners and a soft glow, unlit (the screen makes its own light).
render_mode unshaded, cull_back;

uniform sampler2D feed : source_color, filter_linear;
uniform float on = 1.0;          // 0 when nobody is at the door: a dark, faintly glowing screen

void fragment() {
	vec3 c = texture(feed, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(0.9, 1.0, 0.92), 0.8);
	c *= 1.0 - 0.12 * step(0.5, fract(UV.y * 120.0));
	vec2 d = UV - vec2(0.5);
	c *= 1.0 - 0.45 * smoothstep(0.2, 0.75, length(d * vec2(1.0, 1.2)));
	c = mix(vec3(0.03, 0.05, 0.04), c * 1.15, on);
	ALBEDO = c;
}
