shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(.12,.2,.27,1.0);
uniform float metal = .35;
uniform float rough = .55;
uniform float energy = 0.0;
varying vec3 local;
void vertex() { local = VERTEX; }
float grain(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7))) * 43758.5453); }
void fragment() {
 float footprint = length(fwidth(local)) * 65.0;
 float dust = mix(.5, grain(floor(local * 65.0)), clamp(1.0-footprint,0.0,1.0)*.4);
 ALBEDO = paint.rgb * (.95 + dust * .09);
 METALLIC = metal;
 ROUGHNESS = clamp(rough + dust * .08, .2, .95);
 AO = .88;
 EMISSION = paint.rgb * energy;
}
