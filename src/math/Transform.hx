package math;

import math.Matrix;

class Transform {

	// Publics
    public var x(get, set):Float;
    public var y(get, set):Float;
    public var z(get, set):Float;

    public var rotationX(get, set):Float;
    public var rotationY(get, set):Float;
    public var rotationZ(get, set):Float;

    public var scaleX(get, set):Float;
    public var scaleY(get, set):Float;
    public var scaleZ(get, set):Float;

    // Privates
    private var _x:Float = 0;
    private var _y:Float = 0;
    private var _z:Float = 0;

    private var _rotationX:Float = 0;
    private var _rotationY:Float = 0;
    private var _rotationZ:Float = 0;

    private var _scaleX:Float = 1;
    private var _scaleY:Float = 1;
    private var _scaleZ:Float = 1;

	public var matrix:Matrix = new Matrix();
	private var _dirty:Bool = true;

    public function new() {
        
    }

	public function update():Void {
		if (!_dirty) {
            return;
        }
		matrix.identity();
		matrix.appendScale(scaleX, scaleY, scaleZ);
		matrix.appendRotationX(rotationX);
		matrix.appendRotationY(rotationY);
		matrix.appendRotationZ(rotationZ);
		matrix.appendTranslation(x, y, z);
		_dirty = false;
	}

    // Getters and Setters
    private function get_x():Float { return _x; }
    private function set_x(value:Float):Float { _x = value; _dirty = true; return _x; }

    private function get_y():Float { return _y; }
    private function set_y(value:Float):Float { _y = value; _dirty = true; return _y; }

    private function get_z():Float { return _z; }
    private function set_z(value:Float):Float { _z = value; _dirty = true; return _z; }

    private function get_rotationX():Float { return _rotationX; }
    private function set_rotationX(value:Float):Float { _rotationX = value; _dirty = true; return _rotationX; }

    private function get_rotationY():Float { return _rotationY; }
    private function set_rotationY(value:Float):Float { _rotationY = value; _dirty = true; return _rotationY; }

    private function get_rotationZ():Float { return _rotationZ; }
    private function set_rotationZ(value:Float):Float { _rotationZ = value; _dirty = true; return _rotationZ; }

    private function get_scaleX():Float { return _scaleX; }
    private function set_scaleX(value:Float):Float { _scaleX = value; _dirty = true; return _scaleX; }

    private function get_scaleY():Float { return _scaleY; }
    private function set_scaleY(value:Float):Float { _scaleY = value; _dirty = true; return _scaleY; }

    private function get_scaleZ():Float { return _scaleZ; }
    private function set_scaleZ(value:Float):Float { _scaleZ = value; _dirty = true; return _scaleZ; }
}
