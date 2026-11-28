shader_type spatial;
// The Meshy glass counters are one mesh with one painted texture: their glass panes are painted pale grey. This makes them see-through:
// any pale, unsaturated texel is glass. Parts of the counter top (a rectangle in model space, with an optional gap in the middle where
// the mat lies) are glass too, so you can look down into the case. Everything else (wood, brass) stays solid.
// From the shopkeeper's side a display case is solid: the lower panes seen from behind the counter are wood with sliding doors and
// brass pulls, not glass (the case is glass toward the customer and on top, like a real shop counter).
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 top_rect = vec4(-0.46, -0.125, 0.46, 0.125);   // x0, z0, x1, z1 of the glass in the top, model space
uniform vec2 top_y = vec2(0.044, 0.0825);                  // the top slab's underside and top, model space
uniform float top_gap = 0.0;                               // no glass in the top where |x| < this (the mat's place)
uniform float glass_alpha = 0.07;
uniform float screen_base = 0.09;                          // the security screens start above this height (model space)...
uniform float screen_squash = 0.55;                        // ...and are squashed to this share of their height, so their top rail sits below the eye line
uniform bool staff_doors = false;                          // the lower panes seen from your side are wood with sliding doors
uniform float door_width = 0.125;                          // one sliding door's width, model space
uniform float staff_z = -0.27;                             // model z of the front case's back: the shopkeeper's side is beyond it

varying vec3 mpos;
varying vec3 cam_m;                                        // the camera, in model space

void vertex() {
	mpos = VERTEX;
	cam_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
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
	bool in_top = mpos.y > top_y.x && mpos.y < top_y.y && mpos.x > top_rect.x && mpos.x < top_rect.z && mpos.z > top_rect.y && mpos.z < top_rect.w
		&& abs(mpos.x) > top_gap;
	float glass = in_top ? 1.0 : pane;
	// a lower pane seen from the shopkeeper's side: the front case's back (camera behind it), or an arm's panes (camera between the arms)
	bool lower = mpos.y < screen_base - 0.01 && !in_top;
	// (only when the camera is behind the counter, on the shopkeeper's side: from the customer's side it's all glass)
	bool staff_cam = cam_m.z > staff_z;
	bool front_pane = mpos.z < staff_z;
	bool from_behind = staff_doors && lower && pane > 0.5 && staff_cam
		&& ((front_pane && cam_m.z > mpos.z) || (!front_pane && abs(cam_m.x) < abs(mpos.x) - 0.02));
	// the back of a display case, like a shop's: in each section two flat sliding doors, one slid aside so the glass behind it shows
	float along = abs(mpos.x) < 0.3 ? mpos.x : mpos.z;
	float t = fract(along / (door_width * 2.0));
	bool open_gap = t < 0.28;                                   // the gap where one door is slid back: glass, you see in
	if (from_behind && !open_gap) {
		bool front_door = t > 0.62;                             // the nearer of the two overlapping doors
		vec3 wood = front_door ? vec3(0.43, 0.23, 0.11) : vec3(0.38, 0.2, 0.1);
		float e1 = min(abs(t - 0.28), abs(t - 0.62));
		float e2 = abs(t - 1.0);
		float edge = 1.0 - smoothstep(0.0, 0.025, min(e1, e2));
		wood *= 1.0 - 0.35 * edge;                              // each door's darker edge, and the line where they overlap
		float pull = (1.0 - smoothstep(0.006, 0.012, abs(t - 0.67))) * (1.0 - smoothstep(0.018, 0.026, abs(mpos.y + 0.025)));
		wood = mix(wood, vec3(0.86, 0.66, 0.3), pull);           // a slim brass pull at the front door's edge
		ALBEDO = wood;
		ALPHA = 1.0;
		ROUGHNESS = 0.55;
		SPECULAR = 0.35;
	} else {
		ALBEDO = mix(c.rgb, vec3(0.82, 0.9, 0.95), glass * 0.3);
		ALPHA = mix(1.0, glass_alpha, glass);
		ROUGHNESS = mix(0.75, 0.05, glass);
		SPECULAR = mix(0.4, 0.8, glass);
	}
}
