package gui;

import display.Tile;

class Checkbox extends Control {

    // Constants
    public static inline var DEFAULT_TILE_WIDTH:Int = 24;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 24;
    private static inline var LABEL_OFFSET_X:Int = 8;
    private static inline var LABEL_OFFSET_Y:Int = 3;

    // Publics
    public var value(get, set):Bool;
    public var label(get, null):Null<Label>;

    // Privates
    private var __graphic:Tile;
    private var __value:Bool;
    private var __label:Null<Label> = null;

    public function new(value:Bool, x:Float, y:Float, text:String = "") {
        super(x, y);

        __graphic = new Tile(null, 2);
        __graphic.width = DEFAULT_TILE_WIDTH;
        __graphic.height = DEFAULT_TILE_HEIGHT;
        __value = value;
        __type = 'checkbox';

        if (text.length > 0) {
            __label = new Label(text, DEFAULT_TILE_WIDTH + LABEL_OFFSET_X, LABEL_OFFSET_Y);
        }
    }

    override function init():Void {
        __initGraphics();

        __graphic.parent = ____canvas.tilemap;
        __graphic.visible = visible;
        ____canvas.tilemap.addTileInstance(__graphic);
        __width = __graphic.width;
        __height = __graphic.height;

        if (__label != null) {
            @:privateAccess __label.____canvas  = ____canvas;
            @:privateAccess __label.____offsetX = ____offsetX + __x;
            @:privateAccess __label.____offsetY = ____offsetY + __y;
            __label.init();
            __width = DEFAULT_TILE_WIDTH + LABEL_OFFSET_X + __label.width;
        }

        super.init();
    }

    override function release():Void {
        ____canvas.tilemap.removeTileInstance(__graphic);
        if (__label != null) __label.release();

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
        if (__label != null) {
            @:privateAccess __label.____offsetX = ____offsetX + __x;
            @:privateAccess __label.__setGraphicX();
        }
    }

    override function __setGraphicY():Void {
        __graphic.y = ____offsetY + __y;
        if (__label != null) {
            @:privateAccess __label.____offsetY = ____offsetY + __y + LABEL_OFFSET_Y;
            @:privateAccess __label.__setGraphicY();
        }
    }

    // Getters and setters.

    override function set_visible(value:Bool):Bool {
        __graphic.visible = value;
        if (__label != null) __label.visible = value;
        return super.set_visible(value);
    }

    private function get_label():Null<Label> {
        return __label;
    }

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