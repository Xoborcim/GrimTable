shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D pigment:source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D orm:filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D normal_tex:hint_normal,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D finish_mask:filter_linear_mipmap,repeat_disable;
uniform sampler2D paint_regions:filter_linear_mipmap,repeat_disable;
uniform bool paintable=false;
uniform int material_family=0; // 0 armor, 1 organic, 2 stone, 3 industrial/base.
uniform vec4 primary_paint:source_color=vec4(.192,.373,.525,1.0);
uniform vec4 secondary_paint:source_color=vec4(.773,.741,.647,1.0);
uniform vec4 trim_paint:source_color=vec4(.627,.553,.373,1.0);
uniform float normal_strength=.65;
uniform float ao_strength=.38;
uniform bool workshop_enabled=false;
uniform sampler2D region_ids:filter_nearest,repeat_disable;
uniform vec4 cloth_paint:source_color=vec4(.40,.35,.28,1.0);
uniform vec4 weapon_paint:source_color=vec4(.25,.29,.31,1.0);
uniform vec4 metal_paint:source_color=vec4(.45,.50,.53,1.0);
uniform vec4 glow_paint:source_color=vec4(.38,.82,.83,1.0);
uniform vec4 body_paint:source_color=vec4(.43,.35,.42,1.0);
uniform float wash_amount=.32;
uniform float drybrush_amount=.20;
uniform float highlight_amount=.42;
uniform float weathering_amount=.48;
uniform float metallic_adjust=0.0;
uniform float roughness_adjust=0.0;
uniform float glow_amount=0.0;
uniform bool has_overlay=false;
uniform bool has_markings=false;
uniform sampler2D overlay_tex:source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D marking_tex:source_color,filter_linear_mipmap,repeat_disable;
uniform bool ground_contact=false;
uniform vec3 ground_bounds_min=vec3(0.0);
uniform vec3 ground_bounds_max=vec3(0.0);
varying vec3 object_position;
varying vec3 world_position;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
void vertex(){object_position=VERTEX;world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}

void fragment(){
 vec3 base=texture(pigment,UV).rgb;
 vec3 response=texture(orm,UV).rgb;
 vec4 finish=texture(finish_mask,UV);
 if(paintable){
  vec3 regions=texture(paint_regions,UV).rgb;
  vec3 tint=vec3(1.0)+regions.r*(primary_paint.rgb-vec3(1.0))+regions.g*(secondary_paint.rgb-vec3(1.0))+regions.b*(trim_paint.rgb-vec3(1.0));
  base*=max(tint,vec3(.001));
 }
 float raised=finish.r;
 float dirt=finish.g;
 if(workshop_enabled){
  float region_id=floor(texture(region_ids,UV).r*255.0+.5)-1.0;
  float value=clamp(dot(base,vec3(.2126,.7152,.0722))*2.8,.22,1.3);
  if(region_id==7.0){base=cloth_paint.rgb*value;}
  if(region_id==3.0){base=weapon_paint.rgb*value;}
  if(region_id==14.0){base=metal_paint.rgb*value;}
  if(region_id==6.0){base=glow_paint.rgb*value;EMISSION=glow_paint.rgb*glow_amount*.7;}
  if(material_family==1 && region_id>=8.0 && region_id<=10.0){base*=body_paint.rgb*2.0;}
  if(has_overlay){vec4 ink=texture(overlay_tex,UV);base=mix(base,ink.rgb,ink.a);}
  if(has_markings){vec4 ink=texture(marking_tex,UV);base=mix(base,ink.rgb,ink.a);}
 }
 if(material_family>=2){
  // Legacy palette slots 0/1 are enamel on miniatures, but structural iron
  // on these scenery exports. Keep the industrial family graphite-toned.
  float iron_region=1.0-smoothstep(1.2,1.8,finish.b*15.0);
  float value=dot(base,vec3(.2126,.7152,.0722));
  base=mix(base,vec3(value)*vec3(.85,.95,.96),iron_region*.90);
 }
 if(ground_contact){
  // Dust is strongest on low surviving paving, joining it to shared ash.
  // Baked cavities retain broken outlines; this is not a transparent blur.
  base=mix(base,vec3(.24,.245,.215),clamp(dirt*.7+(1.0-response.r)*.12,0.0,.48));
  vec2 to_edge=min(object_position.xz-ground_bounds_min.xz,ground_bounds_max.xz-object_position.xz);
  float rim=1.0-smoothstep(.10,2.20,min(to_edge.x,to_edge.y));
  // Cut small embedded pieces from the cosmetic floor margin so the real
  // ground shows through. Keep this opaque; no blended transparency pass.
  float remnant=hash2(floor(world_position.xz/vec2(.43,.57)));
  if(rim*.85>.35+remnant*.60){discard;}
  float deposits=smoothstep(.24,.68,noise2(world_position.xz*2.3));
  float drift=noise2(world_position.xz*.19+vec2(3.1,7.7));
  vec3 ash=mix(vec3(.19,.205,.195),vec3(.29,.295,.265),drift)*(.92+noise2(world_position.xz*7.0)*.10);
  base=mix(base,ash,rim*(.38+deposits*.60));
 }
 if(material_family==1){
  // Carapace highlights follow growth ridges; no metallic chipped-paint layer.
  base=mix(base,base*1.22+vec3(.012,.008,.015),raised*(workshop_enabled ? highlight_amount : .34));
  base=mix(base,base*vec3(.80,.73,.77),dirt*(workshop_enabled ? wash_amount : .22));
  if(workshop_enabled){base=mix(base,base*vec3(.75,.68,.64),dirt*weathering_amount*.35);}
 }else{
  vec3 edge_color=material_family==0 ? vec3(.34,.37,.37) : vec3(.40,.385,.33);
  base=mix(base,base*1.18+edge_color*.12,raised*(workshop_enabled ? highlight_amount : (material_family==0 ? .42 : .32)));
  base=mix(base,base*vec3(.55,.52,.46),dirt*(workshop_enabled ? wash_amount : (material_family==0 ? .32 : .74)));
  // Wear is baked from curvature and sparse local pigment loss. Organic
  // surfaces take the separate branch above and never receive armor chips.
  if(material_family==0){base=mix(base,vec3(.20,.225,.23),finish.a*(workshop_enabled ? weathering_amount : .48));}
 }
 if(workshop_enabled){base=mix(base,base*1.3+vec3(.035),raised*drybrush_amount*.45);}
 // Local AO is deliberately mild. No scene sun or world lighting is baked.
 ALBEDO=base*(1.0-(1.0-response.r)*.10);
 AO=mix(1.0,response.r,ao_strength);
 AO_LIGHT_AFFECT=0.0;
 ROUGHNESS=clamp(response.g+(workshop_enabled ? roughness_adjust : 0.0),.25,.98);
 METALLIC=material_family==1 ? 0.0 : clamp(response.b+(workshop_enabled ? metallic_adjust : 0.0),0.0,1.0);
 NORMAL_MAP=texture(normal_tex,UV).rgb;
 NORMAL_MAP_DEPTH=normal_strength;
}
