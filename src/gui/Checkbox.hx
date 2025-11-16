package gui;

import display.Tile;

class Checkbox extends Control {

    // ** Publics.

    public var value(get, set):Bool;

    // ** Privates.

    private var __graphic:Tile;
    private var __value:Bool;

    public function new(value:Bool, x:Float, y:Float) {
        
        super(x, y);

        __graphic = new Tile(null, 2);
        __graphic.width = 28;
        __graphic.height = 28;
        __value = value;
        __type = 'checkbox';
    }

    override function init():Void {

        __initGraphics();

        __graphic.parent = ____canvas.tilemap;

        __graphic.visible = visible;

        ____canvas.tilemap.addTileInstance(__graphic);

        __width = __graphic.width;

        __height = __graphic.height;

        super.init();
    }

    override function release():Void {

        ____canvas.tilemap.removeTileInstance(__graphic);

        super.release();
    }

    override function update():Void {

        super.update();
    }

    override function onMouseLeftClick():Void {

        value = __value ? false : true;

        super.onMouseLeftClick();
    }

    private function __initGraphics():Void {

        __graphic.regionId = ____canvas.sets.get('checkbox_0');
    }

    override function __setGraphicX():Void {

        __graphic.x = ____offsetX + __x;
    }

    override function __setGraphicY():Void {

        __graphic.y = ____offsetY + __y;
    }

    // ** Getters and setters.

    private function get_value():Bool {
        
        return __value;
    }

    private function set_value(value:Bool):Bool {

        if (value) {

            __graphic.regionId = ____canvas.sets.get('checkbox_1');
        }
        else {

            __graphic.regionId = ____canvas.sets.get('checkbox_0');
        }

        return __value = value;
    }
}