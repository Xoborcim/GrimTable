shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint: source_color=vec4(.4,.4,.35,1.0);
uniform float metal=0.0;
uniform float roughness=.9;
uniform bool use_atlas=false;
uniform sampler2D pigment:source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D orm:filter_linear_mipmap,repeat_disable;
uniform float damage=.4;
varying vec3 world;
varying vec3 local_normal;
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 float mottling=noise(world*1.4);
 float grit=noise(world*11.0);
 float dirt=smoothstep(.48,.82,noise(world*.38));
 vec3 color=texture(pigment,UV).rgb;
 ALBEDO=(use_atlas ? color*paint.rgb : paint.rgb)*(.80+mottling*.22+grit*.055);
 ALBEDO=mix(ALBEDO,vec3(.12,.10,.075),dirt*.25);
 float streak=smoothstep(.55,.8,noise(world*vec3(2.0,.15,2.0)))*damage;
 ALBEDO=mix(ALBEDO,ALBEDO*vec3(.57,.49,.38),streak*.38);
 vec2 response=texture(orm,UV).gb;
 if(use_atlas){
  vec2 wall=vec2(world.x+world.z,world.y);
  wall.x+=mod(floor(wall.y/.48),2.0)*.58;
  vec2 course=abs(fract(wall/vec2(1.16,.48))-.5);
  float seam=smoothstep(.472,.499,max(course.x,course.y));
  float masonry=(1.0-step(.15,response.y))*(1.0-abs(local_normal.y));
  ALBEDO*=1.0-seam*masonry*.25;
 }
 ROUGHNESS=clamp((use_atlas ? response.x : roughness)+grit*.05,0.0,1.0);METALLIC=use_atlas ? response.y : metal;
}
