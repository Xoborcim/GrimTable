shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment(){
 ALBEDO=vec3(.025,.035,.038);
 ALPHA=(1.0-smoothstep(.12,.50,length(UV-vec2(.5))))*.42;
}
