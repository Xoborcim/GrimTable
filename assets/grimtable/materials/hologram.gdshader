shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(.8,.79,.71,1.0);
uniform float contested = 0.0;
uniform float pulse = 0.0;
void fragment() {
 vec3 color = tint.rgb;
 if (contested > .5) color = mix(vec3(.27,.7,.62),vec3(.75,.52,.25),step(.5,UV.x));
 float bands = .6 + .4 * smoothstep(.35,.55,fract(UV.y * 14.0 - TIME * .22));
 ALBEDO = color;
 EMISSION = color * (.6 + pulse);
 ALPHA = bands * (.32 + pulse * .18) * (.88 + .12 * sin(TIME * 1.2));
}
