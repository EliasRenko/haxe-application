package gui;

import gui.Stamp;
import events.ControlEventType;

class Window extends Container<Control> {

    // ** Privates.

    private var __strip:WindowStrip;
    private var __panel:WindowPanel;

    public function new(text:String, width:Float, heigth:Float, x:Float, y:Float) {
        
        super(width, heigth, x, y);

        __strip = new WindowStrip(text, width);
        __strip.stamp_close.addListener(__onCloseClickEvent, LEFT_CLICK);
        __strip.stamp_fold.addListener(__onFoldClickEvent, LEFT_CLICK);

        __panel = new WindowPanel(width, height - 24, 0, 24);

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

    // ** Publics.

    public var label:Label;
    public var stamp_close:Stamp;
    public var stamp_fold:Stamp;

    public function new(title:String, width:Float) {
        
        super(width, 0, 0);

        label = new Label(title, 4, 2);
        stamp_close = new Stamp(0, width - 20, 4);
        stamp_fold = new Stamp(0, width - 36, 8);
    }

    override function init():Void {

        super.init();

        // if (control.active) return control;
        super.addControl(label);
        super.addControl(stamp_close);
        super.addControl(stamp_fold);
    }

    override function __initGraphics() {

        __threeSlice.get(0).id = ____canvas.sets.get('windowStrip_0');
        __threeSlice.get(1).id = ____canvas.sets.get('windowStrip_1');
        __threeSlice.get(2).id = ____canvas.sets.get('windowStrip_2');

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
        __nineSlice.get(0).id = ____canvas.sets.get('windowPanel_0');
        __nineSlice.get(1).id = ____canvas.sets.get('windowPanel_1');
        __nineSlice.get(2).id = ____canvas.sets.get('windowPanel_2');
        __nineSlice.get(3).id = ____canvas.sets.get('windowPanel_3');
        __nineSlice.get(4).id = ____canvas.sets.get('windowPanel_4');
        __nineSlice.get(5).id = ____canvas.sets.get('windowPanel_5');
        __nineSlice.get(6).id = ____canvas.sets.get('windowPanel_6');
        __nineSlice.get(7).id = ____canvas.sets.get('windowPanel_7');
        __nineSlice.get(8).id = ____canvas.sets.get('windowPanel_8');
    }
}