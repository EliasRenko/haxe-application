package input;

import haxe.ds.Vector;

class Mouse {
    
    // Publics
    public var x(get, null):Float = 0;
    public var y(get, null):Float = 0;

    // Privates
    private var __x:Float = 0;
    private var __y:Float = 0;
    private var __checkCount:Int = 0;
	private var __pressCount:Int = 0;
	private var __releaseCount:Int = 0;
	private var __checkControls:Vector<Bool>;
	private var __pressControls:Array<Int>;
	private var __releaseControls:Array<Int>;

    public function new() {
        __checkControls = new Vector(8);
        __pressControls = new Array();
        __releaseControls = new Array();
    }

    public function init():Void {

    }

    public function check(control:Int):Bool{
		return control < 0 ? __checkCount > 0 : __checkControls[control];
	}
	
	public function pressed(control:Int):Bool {
		return control < 0 ? __pressCount > 0 : __pressControls.indexOf(control) >= 0;
	}
	
	public function released(control:Int):Bool {
		return control < 0 ? __releaseCount > 0 : __releaseControls.indexOf(control) >= 0;
	}

    private function __indexOf(vector:Array<Int>, index:Int):Int {
		for (i in 0...vector.length) {
			if (vector[i] == index) {
				return i;
			}
		}
		
		return -1;
	}

    public function update():Void {
        
    }

    public function postUpdate():Void {

		while (__pressCount > 0) {
			__pressControls[-- __pressCount] = -1;
		}
		
		while (__releaseCount > 0) {
			__releaseControls[-- __releaseCount] = -1;
		}
    }

    private function onButtonDown(x:Float, y:Float, button:Int):Void {
        __checkControls[button] = true;
		__checkCount ++;
		__pressControls[__pressCount ++] = button;
    }

    private function onButtonUp(x:Float, y:Float, button:Int):Void {
        __checkControls[button] = false;
		__checkCount --;
		__releaseControls[__releaseCount ++] = button;
    }

    private function onMouseMotion(x:Float, y:Float, xrel:Float, yrel:Float):Void {
        __x = x;
        __y = y;
    }

    // Getters and setters
    private function get_x():Float {
        return __x;
    }

    private function get_y():Float {
        return __y;
    }
}

enum ButtonState {
    PRESSED;
    RELEASED;
}
