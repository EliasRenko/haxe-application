package shaders;

import data.Shader;
import math.Matrix;

@:shaderSourceVert("
    #version 330 core

    layout (location = 0) in vec3 aPos;
    layout (location = 1) in vec4 aColor;

    uniform mat4 uMatrix;
    out vec4 vColor;

    void main() {
        gl_Position = uMatrix * vec4(aPos, 1.0);
        vColor = aColor;
    }
")

@:shaderSourceFrag("
    #version 330 core

    in vec4 vColor;
    out vec4 FragColor;

    void main() {
        FragColor = vColor;
    }
")

@:uniform("uMatrix", Matrix)
class LineShader extends Shader {
    public function new() {
        super();
    }
}
