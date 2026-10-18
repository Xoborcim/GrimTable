shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D relief:hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D cavity:filter_linear_mipmap,repeat_enable;
uniform int base_style=0;
uniform vec4 ground_tint:source_color=vec4(1.0);
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
 vec2 p=local_point.xz*3.0;
 float ao=texture(cavity,p).r;
 vec3 stone=mix(vec3(.13,.145,.13),vec3(.23,.24,.205),ao);
 float joint=1.0-smoothstep(.015,.045,min(abs(fract(p.x)-.5),abs(fract(p.y)-.5)));
 if(base_style==1){
  stone=mix(vec3(.10,.13,.14),vec3(.21,.24,.24),ao);
  stone*=1.0-joint*.26;
 }else if(base_style==2){stone*=1.0-joint*.16;}
 else if(base_style==3){stone=mix(vec3(.12,.125,.115),vec3(.20,.21,.19),ao);}
 ALBEDO=stone*ground_tint.rgb;
 ROUGHNESS=base_style==1 ? .81 : .95;
 METALLIC=base_style==1 ? .32 : 0.0;
 AO=mix(1.0,ao,.20);
 NORMAL_MAP=texture(relief,p).rgb;
 NORMAL_MAP_DEPTH=base_style==1 ? .08 : .18;
}
