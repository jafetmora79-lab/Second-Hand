shader_type canvas_item;
// "Winter Amber": a warm walnut vignette and a faint film grain over the shop, like an illustrated winter postcard. Drawn on a
// CanvasLayer under the HUD; no screen texture, so it's cheap on the web. It eases off while you inspect a piece, so nothing
// darkens what you're looking at.
uniform float inspection = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = smoothstep(0.25, 0.72, length(p));
	float grain = fract(sin(dot(floor(UV * vec2(640.0, 360.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float a = (edge * 0.18 + grain * 0.025) * (1.0 - inspection * 0.75);
	COLOR = vec4(mix(vec3(0.25, 0.13, 0.07), vec3(0.08), edge), a);
}
