shader_type spatial;
// The Meshy glass counter is one mesh with one painted texture: its glass panes are painted pale grey. This makes them see-through:
// any pale, unsaturated texel is glass. The middle of the counter top (a rectangle in model space) is glass too, so you can look down
// into the case. Everything else (wood, brass) stays solid.
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 top_rect = vec4(-0.46, -0.125, 0.46, 0.125);   // x0, z0, x1, z1 of the glass in the top, model space
uniform vec2 top_y = vec2(0.044, 0.0825);                  // the top slab's underside and top, model space
uniform float glass_alpha = 0.07;
uniform float screen_base = 0.09;                          // the security screens start above this height (model space)...
uniform float screen_squash = 0.55;                        // ...and are squashed to this share of their height, so their top rail sits below the eye line

varying vec3 mpos;

void vertex() {
	mpos = VERTEX;
	if (VERTEX.y > screen_base) {
		VERTEX.y = screen_base + (VERTEX.y - screen_base) * screen_squash;
	}
}

void fragment() {
	vec4 c = texture(tex, UV);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float pane = (1.0 - smoothstep(0.1, 0.2, sat)) * smoothstep(0.42, 0.55, mx);
	bool in_top = mpos.y > top_y.x && mpos.y < top_y.y && mpos.x > top_rect.x && mpos.x < top_rect.z && mpos.z > top_rect.y && mpos.z < top_rect.w;
	float glass = in_top ? 1.0 : pane;
	ALBEDO = mix(c.rgb, vec3(0.82, 0.9, 0.95), glass * 0.3);
	ALPHA = mix(1.0, glass_alpha, glass);
	ROUGHNESS = mix(0.75, 0.05, glass);
	SPECULAR = mix(0.4, 0.8, glass);
}
