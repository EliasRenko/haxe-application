package gui;

import display.Tile;

class ListItem<T:Control> extends Container<T> {

    // ** Publics.

    public var item(get, null):T;

    // ** Privates.

    private var __graphic:Tile;

    public function new(control:T, width:Float, y:Float) {

        super(width, 0, 0, y);

        __addControl(control);

        __graphic = new Tile(null, null);

        __type = 'listitem';
    }

    override function init():Void {

        __graphic.id = ____canvas.sets.get('empty');

        __graphic.parent = ____canvas.tilemap;

        __graphic.visible = false;

        ____canvas.tilemap.addTile(__graphic);

        super.init();

        __height = item.height;

        __graphic.width = __width;

        __graphic.height = __height;
    }

    override function release():Void {

        super.release();
    }

    override function update():Void {

        var control:Control = __controls.first();

        if (control.hitTest()) control.update();

        if (__hover) {

            onMouseHover();
        }
        else {

            onMouseEnter();
        }

        if (____canvas.leftClick) {
             
            onMouseLeftClick();

            if (!__focused) {

                onFocusGain();
            }
        }
    }

    override function onMouseEnter():Void {

        __graphic.visible = true;

        super.onMouseEnter();
    }

    override function onMouseLeave():Void {

        __graphic.visible = false;

        super.onMouseLeave();
    }

    override function __setGraphicX():Void {

        __graphic.x = ____offsetX + __x;
    }

    override function __setGraphicY():Void {

        __graphic.y = ____offsetY + __y;
    }

    // ** Getters and setters.

    private function get_item():T {

        var _first = __controls.first();

        return _first;
    }

    override function set_visible(value:Bool):Bool {

        __controls.first().visible = value;

        return super.set_visible(value);
    }
}