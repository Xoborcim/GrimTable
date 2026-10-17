shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float d = length(UV - vec2(.5)) * 2.0;
 ALBEDO = vec3(.015,.023,.028);
 ALPHA = (1.0-smoothstep(.25,1.0,d)) * .24;
}
