package gui;

import display.Text;

class Label extends Control {

    public var text(get, set):String;

    // ** Privates.

    private var __bitmapText:Text;

    public function new(text:String, x:Float = 0, y:Float = 0) {
        
        super(x, y);

        __bitmapText = new Text(null, text, x, y);

        __type = 'label';
    }

    override function init():Void {
        
        super.init();

        __bitmapText.parent = ____canvas.font;

        __width = __bitmapText.width;

        __height = __bitmapText.height;
    }

    override function release():Void {

        __bitmapText.dispose();

        super.release();
    }

    override function onMouseLeftClick() {

        super.onMouseLeftClick();
    }

    override function __setGraphicX():Void {

        __bitmapText.x = ____offsetX + __x;
    }

    override function __setGraphicY():Void {

        __bitmapText.y = ____offsetY + __y;
    }

    // ** Getters and setters.

    override function get_height():Float {

        return super.get_height();
    }

    public function get_text():String {

        return __bitmapText.text;
    }
    
    public function set_text(text:String):String {
        
        __bitmapText.text = text;
        
        __width = __bitmapText.width;
        
        __height = __bitmapText.height;
        
        return text;
    }

    override function set_visible(value:Bool):Bool {

        __bitmapText.visible = value;

        return super.set_visible(value);
    }

    override function get_width():Float {

        return super.get_width();
    }
}