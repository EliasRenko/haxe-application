package gui;

import display.Tile;
import events.ControlEventType;

class Stamp extends Control {

    // ** Publics.

    public var id(get, set):Int;

    // ** Privates.

    private var __graphic:Tile;

    public function new(id:UInt, x:Float, y:Float) {
        
        super(x, y);

        __graphic = new Tile(id);

        __type = 'stamp';
    }

    override function init():Void {

        super.init();

        //__graphic.parent = ____canvas.tilemap;

        ____canvas.tilemap.addTile(__graphic);

        __graphic.visible = visible;

        __width = __graphic.width;

        __height = __graphic.height;
    }

    override function release():Void {

        ____canvas.tilemap.removeTile(__graphic);

        super.release();
    }

    override function update():Void {

        super.update();
    }

    override function onMouseLeftClick() {
        
        super.onMouseLeftClick();
    }

    override function __setGraphicX():Void {

        __graphic.x = ____offsetX + __x;
    }

    override function __setGraphicY():Void {

        __graphic.y = ____offsetY + __y;
    }

    // ** Getters and setters.

    private function get_id():Int {

        return __graphic.id;
    }
    
    private function set_id(value:Int):Int {
        
        __graphic.id = value;

        __width = __graphic.width;

        __height = __graphic.height;

        return value;
    }

    override function set_visible(value:Bool):Bool {

        __graphic.visible = value;

        return super.set_visible(value);
    }
}