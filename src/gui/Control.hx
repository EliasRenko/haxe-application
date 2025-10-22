package gui;

import EventDispacher;
import gui.events.ControlEventType;

/**
 * Base class for all UI controls
 * Provides core functionality for positioning, sizing, visibility, and input handling
 * 
 * Adapted from haxe-ui for haxe-application architecture
 * Uses EventDispacher for event system and integrates with app.input for mouse/keyboard
 */
class Control extends EventDispacher<Control> {

    // ** Public Properties

    /** Whether this control is active and initialized */
    public var active(get, null):Bool;

    /** Reference to parent Canvas for rendering and input */
    public var canvas(get, null):Canvas;

    /** Height of control in pixels */
    public var height(get, set):Float;

    /** Parent control in hierarchy (null for root controls) */
    public var parent(get, null):Control;

    /** Control type identifier (button, label, panel, etc.) */
    public var type(get, null):String;

    /** Whether control is visible and should be rendered */
    public var visible(get, set):Bool;

    /** Width of control in pixels */
    public var width(get, set):Float;

    /** X position in local coordinates */
    public var x(get, set):Float;

    /** Y position in local coordinates */
    public var y(get, set):Float;

    /** Z depth for layering (higher = front) */
    public var z(get, set):Float;

    // ** Private State

    private var __active:Bool = false;
    private var __focused:Bool = false;
    private var __height:Float = 0;
    private var __hover:Bool = false;
    private var __type:String = "";
    private var __visible:Bool = true;
    private var __width:Float = 0;
    private var __x:Float = 0;
    private var __y:Float = 0;
    private var __z:Float = 0;

    // ** Private References (accessed by Canvas and Container)

    /** Canvas reference - set by Canvas.addControl() */
    @:allow(gui.Canvas)
    @:allow(gui.Container)
    private var ____canvas:Canvas;

    /** X offset from parent container */
    @:allow(gui.Container)
    private var ____offsetX:Float = 0;
    
    /** Y offset from parent container */
    @:allow(gui.Container)
    private var ____offsetY:Float = 0;
    
    /** Parent control reference */
    @:allow(gui.Container)
    private var ____parent:Control;

    /**
     * Create a new control
     * @param x Initial X position
     * @param y Initial Y position
     */
    public function new(x:Float, y:Float) {
        super();
        __x = x;
        __y = y;
    }

    /**
     * Initialize control - called by Canvas when control is added
     * Override in subclasses to create graphics (tiles, text, etc.)
     */
    public function init():Void {
        __active = true;
        __setGraphicX();
        __setGraphicY();
        dispatchEvent(this, INIT);
    }

    /**
     * Release control resources - called when control is removed
     * Override in subclasses to clean up graphics
     */
    public function release():Void {
        clearListeners();
    }

    /**
     * Test if mouse is over this control
     * @return true if mouse is within control bounds
     */
    public function hitTest():Bool {
        if (!__visible) {
            return false;
        }

        var mouseX = ____canvas.mouseX;
        var mouseY = ____canvas.mouseY;
        var controlX = __x + ____offsetX;
        var controlY = __y + ____offsetY;

        if (mouseX > controlX && mouseY > controlY) {
            if (mouseX <= controlX + __width && mouseY <= controlY + __height) {
                return true;
            }
        }

        return false;
    }

    /**
     * Update control state - called every frame by Canvas
     * Handles hover detection and mouse input
     */
    public function update():Void {
        if (__hover) {
            onMouseHover();
        } else {
            onMouseEnter();
        }

        if (____canvas.leftClick) {
            onMouseLeftClick();

            if (!__focused) {
                onFocusGain();
            }
        }
    }

    // ** Event Callbacks - Override in subclasses for custom behavior

    /**
     * Called when left mouse button is clicked on this control
     */
    public function onMouseLeftClick():Void {
        dispatchEvent(this, LEFT_CLICK);
    }

    /**
     * Called every frame while mouse is hovering over control
     */
    public function onMouseHover():Void {
        dispatchEvent(this, ON_HOVER);
    }

    /**
     * Called when mouse enters control area
     */
    public function onMouseEnter():Void {
        __hover = true;
        ____canvas.markedControl = this;
        dispatchEvent(this, ON_MOUSE_ENTER);
    }

    /**
     * Called when mouse leaves control area
     */
    public function onMouseLeave():Void {
        __hover = false;
        dispatchEvent(this, ON_MOUSE_LEAVE);
    }

    /**
     * Called when control size changes
     */
    public function onSizeChange():Void {
        dispatchEvent(this, ON_SIZE_CHANGE);
    }

    /**
     * Called when control parent changes
     */
    public function onParentChange():Void {
        dispatchEvent(this, ON_PARENT_CHANGE);
    }

    /**
     * Called when control position changes
     */
    public function onLocationChange():Void {
        dispatchEvent(this, ON_LOCATION_CHANGE);
    }

    /**
     * Called when control visibility changes
     */
    public function onVisibilityChange():Void {
        dispatchEvent(this, ON_VISIBILITY_CHANGE);
    }

    /**
     * Called when control gains focus
     */
    public function onFocusGain():Void {
        if (__focused) return;
        __focused = true;
        ____canvas.focusedControl = this;
        dispatchEvent(this, ON_FOCUS_GAIN);
    }

    /**
     * Called when control loses focus
     */
    public function onFocusLost():Void {
        __focused = false;
        dispatchEvent(this, ON_FOCUS_LOST);
    }

    // ** Protected Methods - Override in subclasses to update graphics

    /**
     * Update graphic X position when control X changes
     * Override to update tile positions, etc.
     */
    private function __setGraphicX():Void {
        // Override in subclasses
    }

    /**
     * Update graphic Y position when control Y changes
     * Override to update tile positions, etc.
     */
    private function __setGraphicY():Void {
        // Override in subclasses
    }

    /**
     * Set X offset from parent (called by Container)
     */
    private function ____setOffsetX(value:Float):Void {
        ____offsetX = value;
        __setGraphicX();
    }

    /**
     * Set Y offset from parent (called by Container)
     */
    private function ____setOffsetY(value:Float):Void {
        ____offsetY = value;
        __setGraphicY();
    }

    // ** Getters and Setters

    private function get_active():Bool {
        return __active;
    }
    
    private function set_active(value:Bool):Bool {
        __active = value;
        return value;
    }

    private function get_canvas():Canvas {
        return ____canvas;
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
        onSizeChange();
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
