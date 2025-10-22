package gui;

import gui.ThreeSlice;

/**
 * Button - Interactive button control
 * Uses ThreeSlice for scalable rendering
 * 
 * Supports hover and pressed visual states
 */
class Button extends Control {

    // ** Public Properties

    /** Button text label */
    public var text(get, set):String;

    // ** Private State

    private var __text:String = "";
    private var __threeSlice:ThreeSlice;
    private var __state:ButtonState = NORMAL;

    /**
     * Create a new button
     * @param text Button label text
     * @param x Button X position
     * @param y Button Y position
     * @param width Button width (optional)
     * @param height Button height (optional)
     */
    public function new(text:String, x:Float, y:Float, ?width:Float, ?height:Float) {
        super(x, y);

        __text = text;
        __width = width != null ? width : 100;
        __height = height != null ? height : 32;
        __type = 'button';
    }

    /**
     * Initialize button - create ThreeSlice tiles
     */
    override function init():Void {
        super.init();

        // Create ThreeSlice (24px edges, adjustable center)
        __threeSlice = new ThreeSlice(____canvas, 24, 24, __height);
        
        // Get region IDs for button parts
        var leftId = ____canvas.getRegionId("button_0");
        var centerId = ____canvas.getRegionId("button_1");
        var rightId = ____canvas.getRegionId("button_2");
        
        // Fallback to region 0 if not found
        if (leftId == -1) {
            trace("Warning: Button regions not found, using fallback");
            leftId = 0;
            centerId = 0;
            rightId = 0;
        }
        
        // Initialize ThreeSlice
        __threeSlice.init(
            leftId,
            centerId,
            rightId,
            __x + ____offsetX,
            __y + ____offsetY,
            __width
        );

        trace("Button '" + __text + "' initialized with ThreeSlice");
    }

    /**
     * Release button - remove ThreeSlice tiles
     */
    override function release():Void {
        if (__threeSlice != null) {
            __threeSlice.release();
        }

        super.release();
    }

    /**
     * Update button - handle hover/press states
     */
    override function update():Void {
        super.update();
        
        // TODO: Update visual state based on hover/pressed
    }

    /**
     * Called when mouse enters button
     */
    override function onMouseEnter():Void {
        super.onMouseEnter();
        __state = HOVER;
        // TODO: Update ThreeSlice regions for hover state
    }

    /**
     * Called when mouse leaves button
     */
    override function onMouseLeave():Void {
        super.onMouseLeave();
        __state = NORMAL;
        // TODO: Update ThreeSlice regions for normal state
    }

    /**
     * Called when button is clicked
     */
    override function onMouseLeftClick():Void {
        super.onMouseLeftClick();
        __state = PRESSED;
        trace("Button '" + __text + "' clicked!");
        
        // TODO: Visual feedback, then return to hover state
    }

    /**
     * Update ThreeSlice X position when control moves
     */
    override function __setGraphicX():Void {
        if (__threeSlice != null) {
            __threeSlice.setX(__x + ____offsetX);
        }
    }

    /**
     * Update ThreeSlice Y position when control moves
     */
    override function __setGraphicY():Void {
        if (__threeSlice != null) {
            __threeSlice.setY(__y + ____offsetY);
        }
    }

    /**
     * Update button width
     */
    override function set_width(value:Float):Float {
        __width = value;
        if (__threeSlice != null) {
            __threeSlice.setWidth(value);
        }
        onSizeChange();
        return value;
    }

    // ** Getters and Setters

    private function get_text():String {
        return __text;
    }

    private function set_text(value:String):String {
        __text = value;
        // TODO: Update text rendering when Text display is added
        return value;
    }

    override function set_visible(value:Bool):Bool {
        if (__threeSlice != null) {
            __threeSlice.setVisible(value);
        }
        return super.set_visible(value);
    }
}

/**
 * Button visual states
 */
enum ButtonState {
    NORMAL;
    HOVER;
    PRESSED;
}
