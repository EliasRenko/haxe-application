package gui;

/**
 * TabPage - Content container for a single tab in a TabControl.
 *
 * A pure container (no background graphics) that holds the controls
 * belonging to one tab. Visibility is managed by the parent TabControl.
 */
class TabPage extends Container<Control> {

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = 'tabpage';
    }

    public function addControl(control:Control):Control {
        return __addControl(control);
    }

    public function removeControl(control:Control):Void {
        __removeControl(control);
    }

    public function clear():Void {
        __clear();
    }
}
