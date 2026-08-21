package gui;

import display.Text;
import display.Tile;
import Scancode;

class TextField extends Control {

    // Constants
    private static inline var DEFAULT_CARET_HEIGHT:Int = 18;
    private static inline var DEFAULT_TEXT_Y_OFFSET:Int = 5;
    private static inline var BLINK_INTERVAL:Float = 0.5;

    // Publics
    public var defaultText:String = '';
    public var maxCharacters(get, set):Int;
    public var text(get, set):String;
    public var restriction:String;

    // Private
    private var __bitmapText:Text;
    private var __graphic:Tile;
    private var __maxCharacters:Int = -1;
    private var __threeSlice:ThreeSlice = new ThreeSlice();
    private var __blinkTimer:Float = 0;
    private var __blinkOn:Bool = true;

    public function new(text:String, width:Float, x:Float, y:Float) {
        super(x, y);
        __bitmapText = new Text(null, text, 0, 0);
        __graphic = new Tile(null);
        __width = width;
        __height = 24;
        __type = 'textfield';
    }

    override function init():Void {
        __threeSlice.iterate(function (tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });

        __initGraphics();
        __threeSlice.setWidth(__width);

        __bitmapText.font = ____canvas.font;
        __bitmapText.updateTiles();

        __graphic.width  = 2;
        __graphic.height = DEFAULT_CARET_HEIGHT;
        __graphic.visible = false;
        ____canvas.tilemap.addTileInstance(__graphic);

        super.init();
    }

    override function release():Void {
        __threeSlice.iterate(function (tile) {
            ____canvas.tilemap.removeTileInstance(tile);
        });

        ____canvas.tilemap.removeTileInstance(__graphic);
        __bitmapText.dispose();

        super.release();
    }

    override function update() {
        super.update();

        if (__focused) {
            var keyboard = ____canvas.parentState.app.input.keyboard;
            if (keyboard.textInput.length > 0) {
                for (i in 0...keyboard.textInput.length) {
                    var ch = keyboard.textInput.charAt(i);
                    if (restriction != null && !StringTools.contains(restriction, ch)) continue;
                    if (maxCharacters >= 0 && text.length >= maxCharacters) break;
                    text = text + ch;
                }
                onTextInput();
            }

            if (keyboard.released(Scancode.BACKSPACE) && text.length > 0) {
                text = text.substring(0, text.length - 1);
                onTextInput();
            }
        }
    }

    override function tick(dt:Float):Void {
        if (!__focused) return;
        __blinkTimer += dt;
        if (__blinkTimer >= BLINK_INTERVAL) {
            __blinkTimer -= BLINK_INTERVAL;
            __blinkOn = !__blinkOn;
            __graphic.visible = __visible && __blinkOn;
        }
    }

    public function add() {}

    private function __initGraphics():Void {
        var r0 = ____canvas.sets.get('slider_0');
        var r1 = ____canvas.sets.get('slider_1');
        var r2 = ____canvas.sets.get('slider_2');
        var rc = ____canvas.sets.get('caret_0');
        __threeSlice.get(0).regionId = r0 != null ? r0 : 0;
        __threeSlice.get(1).regionId = r1 != null ? r1 : 0;
        __threeSlice.get(2).regionId = r2 != null ? r2 : 0;
        __graphic.regionId = rc != null ? rc : 0;
    }

    override function __setGraphicX():Void {
        __bitmapText.x = __x + ____offsetX + 4;
        __graphic.x = __bitmapText.x + __bitmapText.width;
        __threeSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {
        __bitmapText.y = __y + ____offsetY + DEFAULT_TEXT_Y_OFFSET;
        __graphic.y = __y + ____offsetY + (__height - __graphic.height) * 0.5;
        __threeSlice.setY(__y + ____offsetY);
    }

    override function onFocusGain():Void {
        __blinkTimer = 0;
        __blinkOn    = true;
        __graphic.visible = __visible;
        ____canvas.parentState.app.enableTextInput();
        super.onFocusGain();
    }

    override function onFocusLost():Void {
        __graphic.visible = false;
        ____canvas.parentState.app.disableTextInput();
        super.onFocusLost();
    }

    override function set_visible(value:Bool):Bool {
        if (__active) {
            __threeSlice.iterate(function(tile) { tile.visible = value; });
            __graphic.visible = value && __focused; // cursor only shows when focused
            __bitmapText.visible = value;
        }
        return super.set_visible(value);
    }

    public function onTextInput():Void {
        __graphic.x = __bitmapText.x + __bitmapText.width;
        // Reset blink so the caret is always visible immediately after a keystroke.
        __blinkTimer = 0;
        __blinkOn    = true;
        __graphic.visible = __visible;
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