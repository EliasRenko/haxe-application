package gui;

import gui.ThreeSlice;

class Strip extends Container<Control> {

    // ** Privates.

    private var __threeSlice:ThreeSlice = new ThreeSlice();

    public function new(width:Float, x:Float, y:Float) {
        
        super(width, 24, x, y);

        type = 'strip';
    }

    override function init():Void {

        //__initGraphics();

        __threeSlice.iterate(function (tile) {

            //tile.parent = ____canvas.tilemap;

            tile.visible = visible;

            ____canvas.tilemap.addTile(tile);
        });

        __initGraphics(); // In case of a bug, this line should be removed.

        __threeSlice.setWidth(__width);

        super.init();
    }

    override function release():Void {

        __threeSlice.iterate(function (tile) {

            ____canvas.tilemap.removeTile(tile);
        });

        super.release();
    }

    public function addControl(control:Control):Control {
        
        return __addControl(control);
    }

    public function removeControl(control:Control):Void {
        
        return __removeControl(control);
    }

    public function clear():Void {

        __clear();
    }

    private function __initGraphics():Void {

        __threeSlice.get(0).id = ____canvas.sets.get('strip_0');

        __threeSlice.get(1).id = ____canvas.sets.get('strip_1');

        __threeSlice.get(2).id = ____canvas.sets.get('strip_2');
    }

    override function __setGraphicX():Void {

        __threeSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {
        
        __threeSlice.setY(__y + ____offsetY);
    }

    // ** Getters and setters.

    override function set_width(value:Float):Float {

        __threeSlice.setWidth(value);

        return super.set_width(value);
    }

    override function set_visible(value:Bool):Bool {

        __threeSlice.setVisible(value);

        return super.set_visible(value);
    }
}