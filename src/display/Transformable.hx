package display;

import math.Transform;
import math.Matrix;
import DisplayObject;

class Transformable extends DisplayObject {
    
    public var transform:Transform = new Transform();

    override public function render(cameraMatrix:Matrix):Void {
		if (!visible) return;
		
		transform.update();
		var finalMatrix = Matrix.copy(transform.matrix);
		finalMatrix.append(cameraMatrix);
		
		// Set the transform matrix in uniforms map
		uniforms.set("uMatrix", finalMatrix.data);
	}

}
