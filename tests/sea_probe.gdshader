shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/ocean_common.gdshaderinc"
void fragment(){
	vec2 ij=floor(UV*16.);
	vec2 p=vec2(-140.,-160.)+ij*vec2(18.,24.);
	if(ij.x==15. && ij.y<8.){p=vec2(84.+(mod(ij.y,3.)-1.)*3.,-136.+floor(ij.y/3.)*4.);}
	float packed=floor((sea_surface(p).y+8.)*4096.);
	COLOR=vec4(floor(packed/256.)/255.,mod(packed,256.)/255.,sea_exposure(p,coast_data(p)),1.);
}
