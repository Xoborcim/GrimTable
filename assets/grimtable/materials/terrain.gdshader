shader_type spatial;
uniform vec4 paint : source_color = vec4(.25,.33,.38,1.0);
uniform float metal = .45;
varying vec3 world;
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float dirt = grain(floor(world.xz * 3.0)) * .10 + grain(floor(world.xy * 30.0)) * .035;
 float edge = 1.0 - smoothstep(.012,.045,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
 float seam = step(.965,fract(world.y * 1.35)) * .16;
 vec3 base = paint.rgb * (.83 + dirt - seam);
 base = mix(base, paint.rgb * 1.40, edge * .45);
 float hazard = step(.24,world.y) * step(world.y,.43) * metal;
 vec3 stripe = mix(vec3(.075,.085,.08),vec3(.58,.43,.14),step(.5,fract((world.x + world.z) * 1.6)));
 ALBEDO = mix(base,stripe,hazard);
 METALLIC = metal;
 ROUGHNESS = .72 + dirt;
}
