package gui;

class Toolstrip extends Strip {

    // ** Privates.

    private var __lineWidth:Float = 4;

    private var __spacing:Float = 12;

    public function new(width:Float, x:Float, y:Float) {
        
        super(640, x, y);
    }

    override function init():Void {
        super.init();
        // Re-layout all children using their post-init widths.
        // addControl() may have been called before the canvas was set, so
        // Label-based children (width determined by font tiles) had width=0
        // at positioning time.  Redo the pass now that widths are correct.
        __lineWidth = 4;
        for (control in __controls) {
            control.x = __lineWidth;
            control.y = 5;
            __lineWidth += control.width + __spacing;
        }
    }

    override function addControl(control:Control):Control {

        super.addControl(control);

        control.x = __lineWidth;

        control.y = 5;

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