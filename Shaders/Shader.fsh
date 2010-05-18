//
//  Shader.fsh
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
