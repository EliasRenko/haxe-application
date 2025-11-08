package gui;

import gui.Control;
import events.ControlEventType;
import haxe.ds.List;

class Container<T:Control> extends Control {

    // ** Publics.

    public var controls(get, null):List<T>;

    // ** Privates.

    private var __controls:List<T> = new List<T>();

    public function new(width:Float, height:Float, x:Float, y:Float) {
        
        super(x, y);

        __width = width;

        __height = height;

        __type = 'container';
    }

    override function init():Void {

        super.init();

        for (control in __controls) {

            __initControl(control);
        }
    }

    override function release():Void {

        __clear();

        super.release();
    }

    private function __addControl(control:T):T {
        
        if (control.active) return control;

        if (____canvas != null) {
			
			__initControl(control);
		}

        __controls.add(control);

        control.dispatchEvent(control, ADDED);

        return control;
    }

    private function __removeControl(control:T):Void {

        control.dispatchEvent(control, REMOVED);

        control.release();

		__controls.remove(control);
    }

    private function __clear():Void {
        
        for (control in __controls) {

            __removeControl(control);
        }
	}

    override function update():Void {

        for (control in __controls) {

            if (control.hitTest()) {

                control.update();

                return;
            }
        }

        super.update();
    }

    override function onMouseEnter():Void {

        super.onMouseEnter();
    }

    override function onMouseLeave():Void {

        super.onMouseLeave();
    }

    override function onMouseHover():Void {

        super.onMouseHover();
    }
    
    private function __initControl(control:Control) {
        
        @:privateAccess control.____canvas = ____canvas;

        @:privateAccess control.____offsetX = __x + ____offsetX;
		
        @:privateAccess control.____offsetY = __y + ____offsetY;
        
        @:privateAccess control.____parent = this;

        control.visible = control.visible ? __visible : false;

        control.init();
    }

    override function ____setOffsetX(value:Float):Void {
        
        super.____setOffsetX(value);

        for (control in __controls) {

            @:privateAccess control.____setOffsetX(__x + ____offsetX);
        }
    }

    override function ____setOffsetY(value:Float):Void {
        
        super.____setOffsetY(value);

        for (control in __controls) {

            @:privateAccess control.____setOffsetY(__y + ____offsetY);
        }
    }

    // ** Getters and setters.

    private function get_controls():List<T> {

		return __controls;
    }

    override function set_visible(value:Bool):Bool {

        for (control in __controls) {

            control.visible = value;
        }

        return super.set_visible(value);
    }
    
    override function set_x(value:Float):Float {

        super.set_x(value);

        for (control in __controls) {

            @:privateAccess control.____setOffsetX(__x + ____offsetX);
        }

        return value;
    }

    override function set_y(value:Float):Float {

        super.set_y(value);

        for (control in __controls) {

            @:privateAccess control.____setOffsetY(__y + ____offsetY);
        }

        return value;
    }
}

