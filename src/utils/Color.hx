package utils;

class Color {

	// Publics
	
	public var a:Float;
	public var b:Float;
	public var g:Float;
	public var r:Float;
	public var hexValue(get, set):Int;
	
	// Privates
	
	private var __hexValue:Int;
	
	public function new(value:Int) {
		this.hexValue = value;
	}
	
	private function __setAlpha():Void {
		a = ((__hexValue >> 24) & 0xff) / 255.0;
	}
	
	private function __setBlue():Void {
		b = (__hexValue & 0xff) / 255.0;
	}
	
	private function __setGreen():Void {
		g = ((__hexValue >> 8) & 0xff) / 255.0;
	}
	
	private function __setRed():Void {
		r = ((__hexValue >> 16) & 0xff) / 255.0;
	}
	
	// Getters and setters
	
	private function get_hexValue():Int {
		return __hexValue;
	}
	
	private function set_hexValue(value:Int):Int {
		__hexValue = value;
		
		__setAlpha();
		__setBlue();
		__setGreen();
		__setRed();
		
		return value;
	}
}