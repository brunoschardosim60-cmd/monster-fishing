shader_type spatial;
render_mode cull_disabled;
// Sea turtle carapace. UV holds the normalised shell position (x across, y along, front at -1). Scutes: five vertebral
// plates down the spine, four costal plates per side and a ring of marginals, each with dark seams and amber rays
// fanning from its growth centre (hawksbill / green turtle look). UV (9,9) marks the pale plastron.
uniform vec3 base_color:source_color=vec3(.28,.2,.1);
uniform vec3 ray_color:source_color=vec3(.72,.52,.24);
uniform vec3 seam_color:source_color=vec3(.1,.07,.04);
uniform vec3 plastron_color:source_color=vec3(.86,.78,.55);
varying vec2 shell;
void vertex(){shell=UV;}
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	if(shell.x>8.){ALBEDO=plastron_color;ROUGHNESS=.7;if(!FRONT_FACING)NORMAL=-NORMAL;}
	else{
		vec2 p=shell;float r=length(p);
		vec2 cell;vec2 centre;
		if(r>.86){
			// Marginal ring: 22 plates.
			float a=atan(p.x,-p.y);float k=floor((a/6.2831853+.5)*22.);
			cell=vec2(k,9.);centre=vec2(sin((k+.5)/22.*6.2831853-3.1415926),-cos((k+.5)/22.*6.2831853-3.1415926))*.93;
		}else if(abs(p.x)<.3){
			float k=floor((p.y+1.)*2.5);cell=vec2(0.,k);centre=vec2(0.,(k+.5)/2.5-1.);
		}else{
			float k=floor((p.y+.86)/1.72*4.);cell=vec2(sign(p.x),k);centre=vec2(sign(p.x)*.58,(k+.5)/4.*1.72-.86);
		}
		vec2 d=p-centre;
		// Seams: distance to the nearest boundary of the cell, approximated per region.
		float seam;
		if(r>.86){seam=min(abs(r-.86)*8.,abs(fract((atan(p.x,-p.y)/6.2831853+.5)*22.)-.5)*.0+min(fract((atan(p.x,-p.y)/6.2831853+.5)*22.),1.-fract((atan(p.x,-p.y)/6.2831853+.5)*22.))*.6);}
		else if(abs(p.x)<.3){seam=min(.3-abs(p.x),min(fract((p.y+1.)*2.5),1.-fract((p.y+1.)*2.5))*.4)*3.;}
		else{float f=fract((p.y+.86)/1.72*4.);seam=min(abs(abs(p.x)-.3),min(min(f,1.-f)*.43,.86-r))*3.;}
		float rays=.5+.5*sin(atan(d.x,d.y)*9.+h(cell)*6.);
		float tone=h(cell)*.35;
		vec3 col=mix(base_color*(1.+tone),ray_color,rays*smoothstep(.02,.25,length(d))*.55);
		col=mix(seam_color,col,smoothstep(.0,.06,seam));
		ALBEDO=col;ROUGHNESS=.38;SPECULAR=.6;
		if(!FRONT_FACING)NORMAL=-NORMAL;
	}
}
