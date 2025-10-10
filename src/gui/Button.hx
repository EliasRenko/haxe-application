package gui;

import display.Text;
import gui.Control;

class Button extends Control {

    // ** Publics.

    public var text(get, set):String;

    // ** Privates.

    private var __bitmapText:Text;

    private var __threeSlice:ThreeSlice = new ThreeSlice();
    
    public function new(text:String, width:Float, x:Float, y:Float) {
        
        super(x, y);

        __bitmapText = new Text(null, text, 0, 0);

        __height = 24;

        __width = width;

        type = 'button';
    }

    override function init():Void {

        __threeSlice.iterate(function (tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTile(tile);
        });

        __initGraphics();
        __threeSlice.setWidth(__width);

        __bitmapText.parent = ____canvas.font;

        super.init();
    }

    override function release():Void {

        __threeSlice.iterate(function (tile) {

            ____canvas.tilemap.removeTile(tile);
        });

        __bitmapText.dispose();

        super.release();
    }

    override function update() {
        super.update();
    }

    override public function hitTest():Bool {

        if (__visible) {

            if (____canvas.mouseX > __x + ____offsetX && ____canvas.mouseY > __y + ____offsetY) {

                if (____canvas.mouseX <= width + __x + ____offsetX && ____canvas.mouseY <= height + __y + ____offsetY) {

                    return true;
                }
            }
        }

        return false;
    }

    private function __initGraphics():Void {
        __threeSlice.get(0).id = ____canvas.sets.get('button_0');
        __threeSlice.get(1).id = ____canvas.sets.get('button_1');
        __threeSlice.get(2).id = ____canvas.sets.get('button_2');
    }

    override function __setGraphicX():Void {

        __bitmapText.x = Math.round(__x + ____offsetX + (__width / 2) - (__bitmapText.width / 2));

        __threeSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {

        __bitmapText.y = __y + ____offsetY + 2;

        __threeSlice.setY(__y + ____offsetY);
    }

    // ** Getters and setters.

    private function get_text():String {
        
        return __bitmapText.text;
    }

    private function set_text(value:String):String {

        return __bitmapText.text = value;
    }

    override function set_width(value:Float):Float {

        __bitmapText.x = __x + (value / 2) - (__bitmapText.width / 2);

        __threeSlice.setWidth(value);

        return super.set_width(value);
    }
}