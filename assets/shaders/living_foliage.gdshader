shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/cloud_shadow_global.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool has_normal = false;
uniform float sway = .10;
uniform float tree_height = 10.;
uniform float leaf_flutter = .018;
uniform float wind_strength = .4;
uniform float wind_time = 0.;
uniform vec2 wind_direction = vec2(.9,.43);
varying vec3 world_p;
void vertex() {
    world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    float weight=clamp(VERTEX.y/tree_height,0.,1.);
    float gust=sin(wind_time*1.2+world_p.x*.043+world_p.z*.067)+.35*sin(wind_time*2.4+world_p.z*.12);
    vec2 wind=normalize(wind_direction)*gust*weight*weight*sway*(.25+wind_strength*2.8);
    // Instance rotations must not rotate the prevailing world-space wind.
    VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(wind.x,0.,wind.y);
    VERTEX.y+=sin(wind_time*3.7+world_p.x*2.8+world_p.z*2.)*leaf_flutter*weight*(.3+wind_strength*2.);
}
void fragment() {
    vec4 tex=texture(albedo_tex,UV);
    ALBEDO=tex.rgb*tint.rgb*COLOR.rgb*mix(1.,.58,cloud_shadow_g(world_p.xz));
    ALPHA=tex.a;ALPHA_SCISSOR_THRESHOLD=.42;
    if(!FRONT_FACING)NORMAL=-NORMAL;
    if(has_normal){NORMAL_MAP=texture(normal_tex,UV).rgb;NORMAL_MAP_DEPTH=.45;}
    ROUGHNESS=.88;BACKLIGHT=ALBEDO*.24;
}
