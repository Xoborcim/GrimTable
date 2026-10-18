shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
uniform vec4 tint:source_color=vec4(.45,.48,.47,.12);
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){float a=1.0-smoothstep(.05,.5,length(UV-.5));ALBEDO=tint.rgb;ALPHA=a*a*tint.a*COLOR.a;}
