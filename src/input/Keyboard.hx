package input;

import haxe.ds.Vector;

class Keyboard {

    // Privates
    private var __checkControls:Vector<Bool>;
    public var __checkCount:Int = 0;
    private var __pressControls:Array<Int>;
    private var __pressCount:Int = 0;
	private var __releaseControls:Array<Int>;
	private var __releaseCount:Int = 0;

    public function new() {
        __checkControls = new Vector<Bool>(312);
        __pressControls = [];
        __releaseControls = [];
    }

    public static function init():Void {

    }

    public function check(control:Int):Bool{
		return control < 0 ? __checkCount > 0 : __checkControls[control];
	}

    public function pressed(keyCode:Int):Bool {
        return keyCode < 0 ? __pressCount > 0 : __pressControls.indexOf(keyCode) >= 0;
    }

    public function released(keyCode:Int):Bool {
        return keyCode < 0 ? __releaseCount > 0 : __releaseControls.indexOf(keyCode) >= 0;
    }

    public function update():Void {
        
    }

    public function postUpdate():Void {
        // Clear pressed/released arrays for next frame
        __pressControls = [];
        __pressCount = 0;
        __releaseControls = [];
        __releaseCount = 0;
    }

    private function onKeyDown(key:UInt, repeat:Bool, mod:Int):Void {
        // Only register as pressed if not already down (not a repeat)
        if (!__checkControls[key]) {
            __checkControls[key] = true;
            __checkCount++;
            __pressControls.push(key);
            __pressCount++;
        }
    }

    private function onKeyUp(key:UInt, repeat:Bool, mod:Int):Void {
        trace("key up: " + Keycode.toString(key));
        __checkControls[key] = false;
		__checkCount--;
		__releaseControls.push(key);
		__releaseCount++;
    }
}

enum KeyState {
    PRESSED;
    RELEASED;
}
