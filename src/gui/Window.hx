package gui;

import gui.Stamp;
import gui.ControlEventType;
import input.MouseControl;

class Window extends Container<Control> {

    public static inline var DEFAULT_TILE_WIDTH:Int = 24;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 24;

    // Privates
    private var __strip:WindowStrip;
    private var __panel:WindowPanel;

    private var __dragging:Bool = false;
    private var __dragOffsetX:Float = 0;
    private var __dragOffsetY:Float = 0;
    private var __onFocusStack:Bool = false;

    public function new(text:String, width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);

        __strip = new WindowStrip(text, width);
        __strip.stamp_close.addListener(__onCloseClickEvent, LEFT_CLICK);
        __strip.stamp_fold.addListener(__onFoldClickEvent, LEFT_CLICK);

        __panel = new WindowPanel(width, height - DEFAULT_TILE_HEIGHT, 0, DEFAULT_TILE_HEIGHT);

        __type = 'window';
    }

    override function init():Void {

        __addControl(__strip);
        __addControl(__panel);

        super.init();
    }

    public function addControl(control:Control):Control {
        if (____canvas != null) ____canvas.beginGroupTag(this);
        var result = __panel.addControl(control);
        if (____canvas != null) ____canvas.endGroupTag();
        return result;
    }

    public function removeControl(control:Control):Void {
        __panel.removeControl(control);
    }
    
    public function clear():Void {
        __panel.clear();
    }

    override function isCapturing():Bool {
        return __dragging;
    }

    override function hitTest():Bool {
        return __dragging || super.hitTest();
    }

    override function set_visible(value:Bool):Bool {
        if (value && !__onFocusStack && ____canvas != null) {
            __onFocusStack = true;
            ____canvas.pushModalFocus(this);
        } else if (!value && __onFocusStack && ____canvas != null) {
            __onFocusStack = false;
            ____canvas.popFocus(this);
        }
        return super.set_visible(value);
    }

    override function update():Void {
        var mouse = ____canvas.parentState.app.input.mouse;

        if (!__dragging && mouse.pressed(MouseControl.LEFT) && __strip.hitTest()) {
            __dragging = true;
            __dragOffsetX = ____canvas.mouseX - __x;
            __dragOffsetY = ____canvas.mouseY - __y;
        }

        if (__dragging) {
            if (mouse.check(MouseControl.LEFT)) {
                x = ____canvas.mouseX - __dragOffsetX;
                y = ____canvas.mouseY - __dragOffsetY;
            } else {
                __dragging = false;
            }
        }

        super.update();
    }

    private function __onCloseClickEvent(control:Control, type:UInt):Void {
        visible = visible ? false : true;
    }

    private function __onFoldClickEvent(control:Control, type:UInt):Void {
        __panel.visible = __panel.visible ? false : true;
    }
}

private class WindowStrip extends Strip {

    // Constants
    public static inline var DEFAULT_TILE_WIDTH:Int = 20;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 20;
    public static inline var DEFAULT_STAMP_X_OFFSET:Int = -2;
    public static inline var DEFAULT_STAMP_Y_OFFSET:Int = 2;

    // Publics
    public var label:Label;
    public var stamp_close:Stamp;
    public var stamp_fold:Stamp;

    public function new(title:String, width:Float) {
        super(width, 0, 0);

        label = new Label(title, 5, 5);
        stamp_close = new Stamp(26, width - DEFAULT_TILE_WIDTH + DEFAULT_STAMP_X_OFFSET, DEFAULT_STAMP_Y_OFFSET);
        stamp_fold = new Stamp(28, width - (2 * DEFAULT_TILE_WIDTH) + DEFAULT_STAMP_X_OFFSET, DEFAULT_STAMP_Y_OFFSET);
    }

    override function init():Void {

        super.init();

        // if (control.active) return control;
        super.addControl(label);
        super.addControl(stamp_close);
        super.addControl(stamp_fold);
    }

    override function __initGraphics() {

        __threeSlice.get(0).regionId = ____canvas.sets.get('windowStrip_0');
        __threeSlice.get(1).regionId = ____canvas.sets.get('windowStrip_1');
        __threeSlice.get(2).regionId = ____canvas.sets.get('windowStrip_2');

        stamp_close.id = ____canvas.sets.get('stamp_close');
        stamp_fold.id = ____canvas.sets.get('stamp_fold');
    }

    override function update() {
        super.update();
    }
}

private class WindowPanel extends Panel {

    public function new(width:Float, heigth:Float, x:Float, y:Float) {
        super(width, heigth, x, y);
    }

    override function __initGraphics() {
        __nineSlice.get(0).regionId = ____canvas.sets.get('panel_3');
        __nineSlice.get(1).regionId = ____canvas.sets.get('panel_4');
        __nineSlice.get(2).regionId = ____canvas.sets.get('panel_5');
        __nineSlice.get(3).regionId = ____canvas.sets.get('panel_3');
        __nineSlice.get(4).regionId = ____canvas.sets.get('panel_4');
        __nineSlice.get(5).regionId = ____canvas.sets.get('panel_5');
        __nineSlice.get(6).regionId = ____canvas.sets.get('panel_6');
        __nineSlice.get(7).regionId = ____canvas.sets.get('panel_7');
        __nineSlice.get(8).regionId = ____canvas.sets.get('panel_8');
    }
}