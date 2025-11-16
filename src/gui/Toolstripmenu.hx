package gui;

import gui.List;
import gui.Strip;
import gui.ControlEventType;

class Toolstripmenu extends Container<Control> {

    // ** Privates.

    private var __strip:ToolstripBar;

    private var __focusedPanel:Control;

    public function new() {
        
        super(640, 24, 0, 0);

        __strip = new ToolstripBar();

        __type = 'toolstrip';
    }

    override function init():Void {

        __addControl(__strip);

        super.init();
    }

    public function addItem(text:String, options:Array<String>):Label {
        
        //var lastControl:Control = __strip.getLastControl();
        //var position:Float = lastControl != null ? lastControl.y + lastControl.height : 0;

        // **

        var _toolstripPanel:ToolstripPanel = new ToolstripPanel(128, 0, 24);

        ____canvas.addControl(_toolstripPanel);

        var _label:ToolstripLabel = new ToolstripLabel(text, _toolstripPanel, 0, 0);

        _label.addListener(__onItemClickEvent, LEFT_CLICK);

        __strip.addControl(_label);

        // ** 

        for (option in options) {
            _toolstripPanel.addControl(new Label(option, 8, 2));
        }

        return _label;
    }

    public function removeItem(label:Label):Void {
        
        __strip.removeControl(label);
    }

    override function update():Void {

        super.update();   
    }

    private function __onItemClickEvent(control:Control, type:UInt):Void {
        
        var _toolstripLabel:ToolstripLabel = cast control;

        //_toolstripLabel.toolstripPanel.onFocusGain();
    }
}

private class ToolstripLabel extends Label {

    public var toolstripPanel:ToolstripPanel;

    public function new(text:String, panel:ToolstripPanel, x:Float, y:Float) {

        toolstripPanel = panel;

        toolstripPanel.visible = false;

        super(text, x, y);
    }

    override function release():Void {

        ____canvas.removeControl(toolstripPanel);

        super.release();
    }

    override function onFocusGain():Void {

        toolstripPanel.onFocusGain();
    }

    override function set_x(value:Float):Float {

        toolstripPanel.x = value;

        return super.set_x(value);
    }
}

private class ToolstripBar extends Toolstrip {

    public function new() {
        
        super(640, 0, 0);
    }
}

private class ToolstripPanel extends Panel {

    // ** Publics.

    public var list:List<Control>;

    public function new(width:Float, x:Float, y:Float) {
        
        super(width, 0, x, y);

        list = new List(width, 0, 0);
    }

    override function init():Void {

        super.init();

        super.addControl(list);
    }

    override function addControl(control:Control):Control {

        list.addControl(control);

        height = list.height;

        return control;
    }

    override function removeControl(control:Control):Void {

        list.removeControl(control);

        height = list.height;
    }

    public function removeControlAt(index:UInt):Void {
        
        list.removeControlAt(index);

        height = list.height;
    }

    override function onFocusGain():Void {

        visible = true;

        super.onFocusGain();
    }

    override function onFocusLost():Void {

        visible = false;

        super.onFocusLost();
    }
}