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
 float worn = smoothstep(.74,.94,grain(floor(local*24.0)));
 float dirt = (1.0-smoothstep(.05,.55,local.y))*.13;
 ALBEDO = mix(paint.rgb * (.92 + dust * .09-dirt),paint.rgb*.55+vec3(.16,.14,.1),worn*.20);
 METALLIC = metal;
 ROUGHNESS = clamp(rough + dust * .08, .2, .95);
 AO = .88;
 EMISSION = paint.rgb * energy;
}
