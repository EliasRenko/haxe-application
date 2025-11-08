package gui;

class Toolstrip extends Strip {

    // ** Privates.

    private var __lineWidth:Float = 4;

    private var __spacing:Float = 12;

    public function new(width:Float, x:Float, y:Float) {
        
        super(640, x, y);
    }

    override function addControl(control:Control):Control {

        super.addControl(control);

        control.x = __lineWidth;

        control.y = 2;

        __lineWidth += control.width + __spacing;

        return control;
    }

    override function removeControl(control:Control):Void {
        
        super.removeControl(control);

        __lineWidth = 4;

        for (control in __controls) {
        
            control.x = __lineWidth;

            __lineWidth += control.width + __spacing;
        }
    }
}