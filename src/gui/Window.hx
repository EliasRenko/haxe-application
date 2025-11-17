package gui;

import gui.Stamp;
import gui.ControlEventType;

class Window extends Container<Control> {

    public static inline var DEFAULT_TILE_WIDTH:Int = 28;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 28;

    // ** Privates.

    private var __strip:WindowStrip;
    private var __panel:WindowPanel;

    public function new(text:String, width:Float, heigth:Float, x:Float, y:Float) {
        
        super(width, heigth, x, y);

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

        return __panel.addControl(control);
    }

    public function removeControl(control:Control):Void {
        
        __panel.removeControl(control);
    }
    
    public function clear():Void {
        
        __panel.clear();
    }

    private function __onCloseClickEvent(control:Control, type:UInt):Void {

        visible = visible ? false : true;
    }

    private function __onFoldClickEvent(control:Control, type:UInt):Void {

        __panel.visible = __panel.visible ? false : true;
    }
}

private class WindowStrip extends Strip {

    public static inline var DEFAULT_TILE_WIDTH:Int = 28;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 28;

    // ** Publics.

    public var label:Label;
    public var stamp_close:Stamp;
    public var stamp_fold:Stamp;

    public function new(title:String, width:Float) {
        
        super(width, 0, 0);

        label = new Label(title, 4, 2);
        stamp_close = new Stamp(26, width - DEFAULT_TILE_WIDTH, 4);
        stamp_fold = new Stamp(28, width - (2 * DEFAULT_TILE_WIDTH), 8);
    }

    override function init():Void {

        super.init();

        // if (control.active) return control;
        super.addControl(label);
        super.addControl(stamp_close);
        super.addControl(stamp_fold);
    }

    override function __initGraphics() {

        __threeSlice.get(0).regionId = ____canvas.sets.get('strip_1');
        __threeSlice.get(1).regionId = ____canvas.sets.get('strip_2');
        __threeSlice.get(2).regionId = ____canvas.sets.get('strip_3');

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
        __nineSlice.get(0).regionId = ____canvas.sets.get('panel_1');
        __nineSlice.get(1).regionId = ____canvas.sets.get('panel_2');
        __nineSlice.get(2).regionId = ____canvas.sets.get('panel_3');
        __nineSlice.get(3).regionId = ____canvas.sets.get('panel_4');
        __nineSlice.get(4).regionId = ____canvas.sets.get('panel_5');
        __nineSlice.get(5).regionId = ____canvas.sets.get('panel_6');
        __nineSlice.get(6).regionId = ____canvas.sets.get('panel_7');
        __nineSlice.get(7).regionId = ____canvas.sets.get('panel_8');
        __nineSlice.get(8).regionId = ____canvas.sets.get('panel_9');
    }
}