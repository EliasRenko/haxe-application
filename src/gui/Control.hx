package gui;

import EventDispacher;
import utils.Rect;
import gui.ControlEvent;
import gui.ControlEventType;

class Control extends EventDispacher<Control> {

    // ** Publics.

    public var active(get, null):Bool;

    public var canvas(get, null):Canvas;

    public var height(get, set):Float;

    public var parent(get, null):Control;

    public var type(get, null):String;

    public var visible(get, set):Bool;

    public var width(get, set):Float;

    public var x(get, set):Float;

    public var y(get, set):Float;

    public var z(get, set):Float;

    // ** Privates.

    private var __active:Bool = false;

    private var __focused:Bool = false;

    private var __height:Float;

    private var __hitbox:Rect;

    private var __hover:Bool = false;

    private var __type:String = "";

    private var __visible:Bool = true;

    private var __width:Float;

    private var __x:Float;

    private var __y:Float;

    private var __z:Float;

    // ** Privates with access.

    public var ____canvas:Canvas;

    @:noCompletion private var ____offsetX:Float = 0;
	
    @:noCompletion private var ____offsetY:Float = 0;
    
    @:noCompletion private var ____parent:Control;

    public function new(x:Float, y:Float) {

        super();

        __x = x;

        __y = y;
    }

    public function init():Void {
        
        __active = true;

        __setGraphicX();

        __setGraphicY();

        dispatchEvent(this, INIT);
    }

    public function release():Void {

        //clearEventListeners();
    }

    public function hitTest():Bool {
        
        if (__visible) {

            if (____canvas.mouseX > __x + ____offsetX && ____canvas.mouseY > __y + ____offsetY) {

                if (____canvas.mouseX <= width + __x + ____offsetX && ____canvas.mouseY <= height + __y + ____offsetY) {

                    return true;
                }
            }
        }

        return false;
    }

    public function update():Void {
        
        if (__hover) {

            onMouseHover();
        }
        else {

            onMouseEnter();
        }

        if (____canvas.leftClick) {
             
            onMouseLeftClick();

            if (!__focused) {

                onFocusGain();
            }
        }
    }

    public function onMouseLeftClick():Void {

        dispatchEvent(this, LEFT_CLICK);
    }

    public function onMouseHover():Void {
        
        dispatchEvent(this, ON_HOVER);
    }

    public function onMouseEnter():Void {
        
        __hover = true;

        ____canvas.markedControl = this;

        dispatchEvent(this, ON_MOUSE_ENTER);
    }

    public function onMouseLeave():Void {
        
        __hover = false;

        dispatchEvent(this, ON_MOUSE_LEAVE);
    }

    public function onSizeChange():Void {
        
        dispatchEvent(this, ON_SIZE_CHANGE);
    }

    public function onParentChange():Void {

    }

    public function onLocationChange():Void {
        
        dispatchEvent(this, ON_LOCATION_CHANGE);
    }

    public function onVisibilityChange():Void {
        
        dispatchEvent(this, ON_VISIBILITY_CHANGE);
    }

    public function onFocusGain():Void {
        
        if (__focused) return;

        __focused = true;

        ____canvas.focusedControl = this;
    }

    public function onFocusLost():Void {
        
        __focused = false;
    }

    // ** Privates.

    private function __setGraphicX():Void {}  

    private function __setGraphicY():Void {}

    // ** Privates with access.

    @:noCompletion
    private function ____setOffsetX(value:Float):Void {
        
        ____offsetX = value;

        __setGraphicX();
    }

    @:noCompletion
    private function ____setOffsetY(value:Float):Void {
        
        ____offsetY = value;

        __setGraphicY();
    }

    // ** Getters and setters.

    private function get_active():Bool {

		return __active;
	}
	
	private function set_active(value:Bool):Bool {
        
        __active = value;

		return value;
	}

    private function get_canvas():Canvas {
        
        return canvas;
    }

    private function get_height():Float {

		return __height;
	}
	
	private function set_height(value:Float):Float {
        
        __height = value;

        onSizeChange();

		return value;
    }
    
    private function get_parent():Control {

		return ____parent;
    }
    
    private function get_type():String {
        
        return __type;
    }

    private function get_visible():Bool {

		return __visible;
	}

	private function set_visible(value:Bool):Bool {
        
        __visible = value;

        onVisibilityChange();

		return value;
    }
    
    private function get_width():Float {

		return __width;
	}
	
	private function set_width(value:Float):Float {
        
        __width = value;

		return value;
	}

    private function get_x():Float {

		return __x;
	}
	
	private function set_x(value:Float):Float {

        __x = value;

        __setGraphicX();

        onLocationChange();

		return value;
	}
	
	private function get_y():Float {

		return __y;
	}
	
	private function set_y(value:Float):Float {

        __y = value;

        __setGraphicY();

        onLocationChange();

		return value;
	}
	
	private function get_z():Float {

		return __z;
	}
	
	private function set_z(value:Float):Float {
		
		return __z = value;
	}
}