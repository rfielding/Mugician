//
//  Shader.fsh
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

varying lowp vec4 colorVarying;

//uniform sampler2D textures[1];

void main()
{
    gl_FragColor = colorVarying;
    //gl_FragColor = texture2D(textures[0], texcoord);
	
}
