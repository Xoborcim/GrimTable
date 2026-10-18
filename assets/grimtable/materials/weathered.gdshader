shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint : source_color = vec4(.4,.4,.35,1.0);
uniform float metal = 0.0;
uniform float roughness = .9;
uniform float energy = 0.0;
uniform float hazard = 0.0;
varying vec3 world;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float coarse=noise(world*1.8), grain=noise(world*38.0);
 float stain=smoothstep(.43,.78,noise(world*vec3(3.0,.18,3.0)));
 float chips=step(.78,noise(world*16.0));
 float cracks=1.0-smoothstep(.015,.04,abs(noise(world*4.0)-.5));
 vec3 base=paint.rgb*(.65+coarse*.5+grain*.13);
 base=mix(base,vec3(.19,.105,.055),stain*metal*.38);
 base=mix(base,vec3(.065,.075,.071),cracks*.17+chips*.11);
 vec3 stripe=mix(vec3(.10,.11,.10),paint.rgb,step(.5,fract((world.x+world.z+world.y)*1.1)));
 ALBEDO=mix(base,stripe*(.7+coarse*.3),hazard);
 ROUGHNESS=clamp(roughness+stain*.12+grain*.05,0.0,1.0);
 METALLIC=metal*(1.0-stain*.5);
 NORMAL=normalize(NORMAL+vec3(dFdx(grain)*.035,dFdy(grain)*.035,0.0));
 EMISSION=paint.rgb*energy*.7;
}
