package gui;

import display.Text;
import display.Tile;
import types.KeyboardEvent;
import utils.Common;
import gui.Control;

class TextField extends Control {

    // ** Publics.

    public var defaultText:String = '';
    public var maxCharacters(get, set):Int;
    public var text(get, set):String;
    public var restriction:String;

    // ** Privates.

    private var __bitmapText:Text;
    private var __graphic:Tile;
    private var __maxCharacters:Int = -1;
    private var __threeSlice:ThreeSlice = new ThreeSlice();

    public function new(text:String, width:Float, x:Float, y:Float) {
        
        super(x, y);

        __bitmapText = new Text(null, text, 0, 0);

        __graphic = new Tile(null, null);

        __width = width;

        __height = 24;

        type = 'textfield';
    }

    override function init():Void {

        __threeSlice.iterate(function (tile) {

            //tile.parentTilemap = ____canvas.font;

            tile.visible = visible;

            ____canvas.tilemap.addTile(tile);
        });

        __initGraphics();

        __threeSlice.setWidth(__width);

        //__threeSlice.setZ(z);

        __bitmapText.parent = ____canvas.font;

        //__bitmapText.z = z - 1;

        //__bitmapText.addToParent();

        __graphic.parent = ____canvas.tilemap;

        __graphic.width = 2;

        __graphic.height = ____canvas.font.ascend;

        __graphic.visible = false;

        __graphic.z = z - 1;

        ____canvas.tilemap.addTile(__graphic);

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

        if (__focused) {

            ____canvas.onTextInput(this);

            // if (Common.input.keyboard.pressed(40)) {

            //     ____canvas.focusedControl = null;
            // }
        }
    }

    public function add() {
        
    }

    private function __initGraphics():Void {

        __threeSlice.get(0).id = ____canvas.sets.get('slider_0');

        __threeSlice.get(1).id = ____canvas.sets.get('slider_1');

        __threeSlice.get(2).id = ____canvas.sets.get('slider_2');

        __graphic.id = ____canvas.sets.get('empty');
    }

    override function __setGraphicX():Void {

        __bitmapText.x = __x + ____offsetX + 4;

        __graphic.x = __bitmapText.x + __bitmapText.width;

        __threeSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {

        __bitmapText.y = __y + ____offsetY + 2;

        __graphic.y = __y + ____offsetY;

        __threeSlice.setY(__y + ____offsetY);
    }

    override function onFocusGain():Void {

        //Common.input.keyboard.addEventListener(__onkeyInputEvent, 1);

        //Common.input.keyboard.addEventListener(__onTextInputEvent, 3);
        //canvas.parentState.parent.input.addEventListener(__onTextInputEvent, 3); // TODO: Fix this to use the correct input system.

        //__graphic.visible = true;

        super.onFocusGain();
    }

    override function onFocusLost():Void {

        //Common.input.keyboard.removeEventListener(__onkeyInputEvent);

        //Common.input.keyboard.removeEventListener(__onTextInputEvent);

        //__graphic.visible = false;

        super.onFocusLost();
    }

    public function onTextInput():Void {
        
        __graphic.x = __bitmapText.x + __bitmapText.width;
    }

    private function __onTextInputEvent(event:KeyboardEvent, type:UInt):Void {

        if (maxCharacters > -1) {

            if (text.length >= maxCharacters) {

                return;
            }
        }

        if (restriction != null) {

            if (!StringTools.contains(restriction, event.text)) {

                return;
            }
        }

        text = text + event.text;

        onTextInput();
    }

    private function __onkeyInputEvent(event:KeyboardEvent, type:UInt):Void {
        
        switch (event.key) {

            case 42:

                text = text.substring(0, text.length - 1);

        }

        onTextInput();
    }

    // ** Getters and setters.

    private function get_maxCharacters():Int {
        
        return __maxCharacters;
    }

    private function set_maxCharacters(value:Int):Int {
        
        return __maxCharacters = value;
    }

    private function get_text():String {
        
        return __bitmapText.text;
    }

    private function set_text(text:String):String {

        if (text == null || text == '') {

            text = defaultText;
        }

        return __bitmapText.text = text;
    }
}