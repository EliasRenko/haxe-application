package gui;

import gui.Control;
import gui.events.ControlEventType;

/**
 * Container control - manages a collection of child controls
 * Provides hierarchical positioning and offset management
 * 
 * Generic type T allows for type-safe collections (e.g., Container<Button>)
 * Adapted from haxe-ui for haxe-application architecture
 */
class Container<T:Control> extends Control {

    // ** Public Properties

    /** List of child controls */
    public var controls(get, null):Array<T>;

    // ** Private State

    private var __controls:Array<T> = [];

    /**
     * Create a new container
     * @param width Container width
     * @param height Container height
     * @param x Container X position
     * @param y Container Y position
     */
    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(x, y);
        __width = width;
        __height = height;
        __type = 'container';
    }

    /**
     * Initialize container and all child controls
     */
    override function init():Void {
        super.init();

        for (control in __controls) {
            __initControl(control);
        }
    }

    /**
     * Release container and all child controls
     */
    override function release():Void {
        __clear();
        super.release();
    }

    /**
     * Add a child control to this container
     * @param control Control to add
     * @return The added control
     */
    public function addControl(control:T):T {
        if (control.active) {
            return control;
        }

        if (____canvas != null) {
            __initControl(control);
        }

        __controls.push(control);
        control.dispatchEvent(control, ADDED);
        return control;
    }

    /**
     * Remove a child control from this container
     * @param control Control to remove
     */
    public function removeControl(control:T):Void {
        control.dispatchEvent(control, REMOVED);
        control.release();
        __controls.remove(control);
    }

    /**
     * Clear all child controls from container
     */
    private function __clear():Void {
        for (control in __controls) {
            removeControl(control);
        }
    }

    /**
     * Initialize a child control with canvas and offset references
     */
    private function __initControl(control:T):Void {
        // Set canvas reference
        @:privateAccess control.____canvas = ____canvas;

        // Set offset from this container
        @:privateAccess control.____offsetX = __x + ____offsetX;
        @:privateAccess control.____offsetY = __y + ____offsetY;
        
        // Set parent reference
        @:privateAccess control.____parent = this;

        // Inherit visibility
        control.visible = control.visible ? __visible : false;

        // Initialize control
        control.init();
    }

    /**
     * Update container and check for child control hits
     * Propagates update to first hit control
     */
    override function update():Void {
        // Check children first (front to back)
        for (control in __controls) {
            if (control.hitTest()) {
                control.update();
                return;
            }
        }

        // No child hit, update self
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

    /**
     * Update child control X offsets when container X changes
     */
    override function ____setOffsetX(value:Float):Void {
        super.____setOffsetX(value);

        for (control in __controls) {
            @:privateAccess control.____setOffsetX(__x + ____offsetX);
        }
    }

    /**
     * Update child control Y offsets when container Y changes
     */
    override function ____setOffsetY(value:Float):Void {
        super.____setOffsetY(value);

        for (control in __controls) {
            @:privateAccess control.____setOffsetY(__y + ____offsetY);
        }
    }

    // ** Getters and Setters

    private function get_controls():Array<T> {
        return __controls;
    }

    /**
     * Setting visibility propagates to all children
     */
    override function set_visible(value:Bool):Bool {
        for (control in __controls) {
            control.visible = value;
        }
        return super.set_visible(value);
    }
    
    /**
     * Setting X position updates all child offsets
     */
    override function set_x(value:Float):Float {
        super.set_x(value);

        for (control in __controls) {
            @:privateAccess control.____setOffsetX(__x + ____offsetX);
        }

        return value;
    }

    /**
     * Setting Y position updates all child offsets
     */
    override function set_y(value:Float):Float {
        super.set_y(value);

        for (control in __controls) {
            @:privateAccess control.____setOffsetY(__y + ____offsetY);
        }

        return value;
    }
}
