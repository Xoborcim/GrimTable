shader_type spatial;
render_mode diffuse_burley;
uniform vec4 ground : source_color = vec4(.14,.18,.2,1.0);
uniform vec4 seam : source_color = vec4(.3,.36,.38,1.0);
uniform float industrial = 1.0;
uniform float grid_visibility = 0.0;
uniform int environment_theme = -1;
uniform bool location_ground=false;
uniform bool location_industrial=false;
uniform sampler2D layout_mask:filter_linear,repeat_disable;
uniform sampler2D relief_normal:hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D relief_ao:filter_linear_mipmap,repeat_enable;
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
 float fracture=1.0-smoothstep(.008,.03,abs(noise(p*1.3+noise(p*.19)*3.0)-.5));
 float scorch=smoothstep(.5,.8,noise(p*.12));
 base=mix(base,vec3(.09,.085,.07),scorch*.6+fracture*.15);
 float road=step(abs(p.x+3.0),2.6);
 float marking=step(abs(abs(p.x+3.0)-2.0),.045)*step(.5,fract(p.y*.17));
 base=mix(base,base*.74,road*.6);
 base=mix(base,vec3(.38,.32,.18),marking*industrial*.55);
 if(environment_theme>=0){
  float broad=noise(p*.095);
  float grit=noise(p*5.0);
  vec2 tile=fract((p+vec2(1.7,0.0))/vec2(2.3,3.1));
  float joint=1.0-smoothstep(.013,.035,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
  float broken=1.0-smoothstep(.006,.024,abs(noise(p*.85+vec2(noise(p*.3)*2.0))-.47));
  float ash=smoothstep(.40,.77,broad);
  vec3 stone=mix(ground.rgb*.72,seam.rgb*.75,hash(floor((p+vec2(1.7,0.0))/vec2(2.3,3.1)))*.25);
  stone*=.9+grit*.14;
  float pavement=max(1.0-smoothstep(5.0,8.0,abs(p.x)),1.0-smoothstep(4.0,8.0,abs(p.y)));
  stone=mix(stone,vec3(.095,.10,.10),joint*.35+broken*.16);
  vec3 margin=mix(ground.rgb*.62,vec3(.23,.235,.215),broad)*(.91+grit*.10);
  base=mix(margin,stone,pavement);
  base=mix(base,vec3(.23,.235,.22),ash*.25);
  if(environment_theme==1 || environment_theme==2){
   vec2 plate=abs(fract(p/vec2(3.5,5.0))-.5);
   float weld=smoothstep(.477,.495,max(plate.x,plate.y));
   float deck=1.0-smoothstep(5.5,7.0,abs(p.x));
   vec3 metal=vec3(.20,.235,.24)*(.85+noise(p*.4)*.22);
   metal=mix(metal,vec3(.075,.085,.083),weld*.8);
   base=mix(base,metal,deck);
   float oil=smoothstep(.57,.78,noise(p*.22+7.0));
   base=mix(base,vec3(.067,.072,.065),oil*.7);
   float stripe=step(.5,fract((p.x+p.y)*.9));
   float border=(1.0-smoothstep(.08,.16,abs(abs(p.x)-6.2)))*step(.3,noise(p*4.0));
   base=mix(base,mix(vec3(.09),vec3(.47,.35,.10),stripe),border*.6);
   if(environment_theme==2){
    float sludge=smoothstep(.50,.76,noise(p*.11+19.0));
    base=mix(base,vec3(.22,.26,.10),sludge*.58);
   }
  }
  if(environment_theme==3){base=mix(vec3(.16,.135,.10),vec3(.27,.235,.17),broad)*(.85+grit*.18);}
 }
 if(location_ground){
  vec2 map_uv=(p+vec2(30.0,22.0))/vec2(60.0,44.0);
  // Low-frequency erosion breaks the old sinusoidal mask outline. This is
  // sub-inch surface wear; the authored centers and gameplay stay fixed.
  map_uv+=(vec2(noise(p*.63+7.0),noise(p*.57-13.0))-.5)*vec2(.9/60.0,.9/44.0);
  vec4 mask=texture(layout_mask,vec2(map_uv.x,1.0-map_uv.y));
  vec2 relief_uv=p/3.7;
  float ao=texture(relief_ao,relief_uv).r;
  float drift=noise(p*.19+vec2(3.1,7.7));
  float grain=noise(p*7.0);
  vec3 ash_ground=mix(vec3(.19,.205,.195),vec3(.29,.295,.265),drift)*(.92+grain*.10);
  // Use the authored edge as a boundary band. Uneven sediment feathers the
  // paving into ash without moving roads, steel yards or damage origins.
  float edge=4.0*mask.r*(1.0-mask.r);
  float sediment=smoothstep(.30,.73,drift*.65+noise(p*1.7)*.35);
  float paving=clamp(mask.r-edge*(.12+sediment*.60),0.0,1.0);
  paving*=1.0-smoothstep(.52,.76,noise(p*.42+vec2(drift*3.0)))*.28;
  // Between surviving paving and ash, expose discrete embedded fragments.
  // Cell outlines are chipped and staggered; their coverage follows the
  // authored material boundary rather than covering the entire battlefield.
  vec2 fragment_uv=p/vec2(.52,.69);
  fragment_uv.x+=mod(floor(fragment_uv.y),2.0)*.5;
  vec2 fragment_cell=floor(fragment_uv);
  vec2 fragment_shape=abs(fract(fragment_uv)-.5);
  float fragment_outline=max(max(fragment_shape.x,fragment_shape.y),dot(fragment_shape,vec2(.78)));
  float buried_stone=(1.0-smoothstep(.31,.43,fragment_outline))*step(.48,hash(fragment_cell));
  float boundary=smoothstep(.015,.35,mask.r)*(1.0-smoothstep(.60,.92,mask.r));
  paving=max(paving,buried_stone*boundary*(.40+hash(fragment_cell+17.0)*.25));
  vec2 courses=p+vec2(.4,0.0);
  courses.x+=mod(floor(courses.y/2.7),2.0)*.95;
  courses+=vec2(noise(p*2.1),noise(p*2.1+11.0))*.10;
  vec2 flags=abs(fract(courses/vec2(1.9,2.7))-.5);
  float mortar=smoothstep(.478,.497,max(flags.x,flags.y));
  vec3 flagstone=vec3(.34,.365,.35)*(.82+noise(p*.8)*.15+noise(p*.13)*.06);
  flagstone*=1.0-mortar*(.06+sediment*.08);
  // Worn aggregate connects modeled flagstones to the lower approach surface.
  flagstone=mix(flagstone,ash_ground,sediment*.18);
  vec3 verge=mix(ash_ground,vec3(.29,.285,.245),sediment*.13);
  base=mix(verge,flagstone,paving);
  vec2 deck=abs(fract(p/vec2(3.1,4.7))-.5);
  float weld=smoothstep(.475,.496,max(deck.x,deck.y));
  vec3 steel=vec3(.22,.26,.27)*(.9+noise(p*.37)*.16)*(1.0-weld*.5);
  float steel_edge=4.0*mask.g*(1.0-mask.g);
  base=mix(base,steel,clamp(mask.g-steel_edge*sediment*.48,0.0,1.0)*.8);
  base=mix(base,vec3(.07,.075,.068),mask.b*.75);
  // Broad fracture branches are localized by the authored damage mask.
  float tear=1.0-smoothstep(.008,.03,abs(noise(p*.65+noise(p*.15)*2.0)-.5));
  base=mix(base,vec3(.075,.08,.075),tear*mask.b*.55);
  base=mix(base,vec3(.075,.075,.065),mask.a*.85);
  base*=1.0-(1.0-ao)*(.06+mask.r*.05);
  NORMAL_MAP=texture(relief_normal,relief_uv).rgb;
  NORMAL_MAP_DEPTH=.035+mask.r*.12;
  if(location_industrial){base=mix(base,base*vec3(.87,.92,.91),.4);}
 }
 ALBEDO=mix(base,seam.rgb,((location_ground ? 0.0 : panel*.025)+grid*grid_visibility*.3)*industrial);
 ROUGHNESS=.86+noise(p*.4)*.10;
 METALLIC=industrial*.08;
}
