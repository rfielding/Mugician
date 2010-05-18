//
//  Shader.vsh
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

attribute vec4 position;
attribute vec4 color;

varying vec4 colorVarying;

uniform float translate;

void main()
{
    gl_Position = position;
    gl_Position.y += sin(4.0*translate) / 8.0;

    colorVarying = color;
}
