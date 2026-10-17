shader_type spatial;
render_mode diffuse_burley;
uniform vec4 ground : source_color = vec4(.14,.18,.2,1.0);
uniform vec4 seam : source_color = vec4(.3,.36,.38,1.0);
uniform float industrial = 1.0;
uniform float grid_visibility = 0.0;
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 p=world.xz;
 float dust=noise(p*.21)*.16+noise(p*.81)*.04;
 vec2 cell=abs(fract(p/vec2(8.0,12.0))-.5);
 float panel=smoothstep(.495,.5,max(cell.x,cell.y));
 vec2 reference=abs(fract(p*.5)-.5);
 float grid=smoothstep(.493-fwidth(p.x)*.15,.5,max(reference.x,reference.y));
 vec3 base=ground.rgb*(.82+dust);
 base=mix(base,vec3(.19,.17,.135),noise(p*.07)*.09);
 ALBEDO=mix(base,seam.rgb,(panel*.045+grid*grid_visibility*.13)*industrial);
 ROUGHNESS=.86+noise(p*.4)*.10;
 METALLIC=industrial*.08;
}
