shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled;
uniform vec4 stain:source_color=vec4(.12,.115,.10,.6);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV-.5;float r=length(p*vec2(.9,1.2));float breakup=noise(UV*13.0);
 ALBEDO=stain.rgb*(.8+breakup*.25);ROUGHNESS=.94;
 ALPHA=(1.0-smoothstep(.18,.46,r+noise(UV*5.0)*.12))*(.55+breakup*.4)*stain.a;
}
