package display;

import data.Indices;
import data.Vertices;
import Renderer;

class Transform extends DisplayObject {

	public var x:Float = 0;
	public var y:Float = 0;
	public var z:Float = 0;

	public var rotationX:Float = 0; // Pitch
	public var rotationY:Float = 0; // Yaw
	public var rotationZ:Float = 0; // Roll

	public var scaleX:Float = 1;
	public var scaleY:Float = 1;

	public function new(renderer:Renderer, vertices:Vertices, indices:Indices) {

        super(renderer, vertices, indices);
    }

    override public function updateTransform():Void {

		matrix.identity();
		matrix.appendScale(scaleX, scaleY, 1);
		matrix.appendRotationX(rotationX);
		matrix.appendRotationY(rotationY);
		matrix.appendRotationZ(-rotationZ * Math.PI / 180.0);
		matrix.appendTranslation(x, y, z);

		super.updateTransform();
	}
}
