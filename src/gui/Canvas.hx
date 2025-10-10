package gui;

import ecs.Entity;
import core.View;
import utils.Rectangle;
import display.Text;
import display.BitmapFont;
import objects.State;
import display.Tile;
import display.Tilemap;
import utils.Common;
import types.TextureTarget;
import haxe.Json;
import math.Matrix;

import gui.Toolstripmenu;
import gui.TextField;


class Canvas extends Entity {
    
    // ** Publics.

    public var dialog(get, set):Dialog;

    public var markedControl(get, set):Control;

    public var focusedControl(get, set):Control;

    public var mouseX(get, null):Int;
	
    public var mouseY(get, null):Int;
    
    public var leftClick(get, null):Bool;

    public var tilemap:Tilemap;

    public var toolstripmenu(get, null):Toolstripmenu;

    public var font:BitmapFont;

    public var width(get, null):Float;

    public var height(get, null):Float;

    // ** Privates.

    private var __container:RootContainer;

    private var __dialog:Dialog;

    private var __markedControl:Control;

    private var __focusedControl:Control;

    public var sets:Map<String, UInt> = new Map<String, UInt>(); //TODO: Make private.

    private var __toolstripmenu:Toolstripmenu;

    public function new(view:View, parentState:State, toolstrip:Bool = true) {
        
        super(0);

        __container = new RootContainer(640, 480);

        @:privateAccess __container.____canvas = this;

        __markedControl = __container;

        __focusedControl = __container;

        // ** Import the sets.

        var programInfo = parentState.app.view.getProgramInfo(parentState.app.resources.getShader('res/shaders/basic.vert'), parentState.app.resources.getShader('res/shaders/basic.frag'));
        var textureId = parentState.app.view.allocTextureMemory(parentState.app.resources.getTexture('res/textures/gui.png'), TextureTarget.TEXTURE_2D);
        tilemap = new Tilemap(view, programInfo, textureId);

        importSets(parentState.app.resources.getText('res/textures/gui.json'));

        var bitmapFontTexture = parentState.app.view.allocTextureMemory(parentState.app.resources.getTexture('res/fonts/nokiafc22.png'), TextureTarget.TEXTURE_2D);

        font = new BitmapFont(parentState.app.view, programInfo, bitmapFontTexture);
        font.regionsFromFile(parentState.app.resources.getText('res/fonts/nokiafc22.json'));

        if (toolstrip) {
            __toolstripmenu = new Toolstripmenu();
            addControl(__toolstripmenu);
        }

        dialog = new Dialog('Intro', 256, 256);
    }

    public function importSets(source:String):Void {
        
        var data:Dynamic = Json.parse(source);

        var index:UInt = 0;

        for (i in 0...data.regions.length) {

            var name:String = data.regions[i].name;

            var dim:Array<Int> = data.regions[i].dim;

            sets.set(name, index);

            tilemap.addRegion(index, dim[0], dim[1], dim[2], dim[3]);

            index ++;
        }
    }

    public function addControl(control:Control):Control {
        
        return __container.addControl(control);
    }

    public function removeControl(control:Control):Void {
        
        return __container.removeControl(control);
    }

    override public function render(cameraMatrix:Matrix):Void {
        
        tilemap.render(cameraMatrix);
        parent.app.view.render(tilemap);

        font.render(cameraMatrix);
        parent.app.view.render(font);
    }

    override public function update(delta:Float):Void {

        if (__dialog.visible) {
            __dialog.update();
            return;
        }

        __container.update();
    }

    public function onTextInput(textfield:TextField):Void {

        var pressedKeys = parent.app.input.keyboard.getAllPressed();

        for (key in pressedKeys) {
            if (key == 8) { // Backspace
                textfield.text = textfield.text.substr(0, textfield.text.length - 1);
            } else if (key == 13) { // Enter
                //textfield.onEnter();
            } else if (key == 27) { // Escape
                //textfield.onEscape();
            } else {
                var char = String.fromCharCode(key);
                textfield.text += char;
            }
        }
    }

    // public function stopTextInput(textfield:Textfield):Void {

    // }

    // ** Getters and setters.

    private function get_dialog():Dialog {
        
        return __dialog;
    }

    private function set_dialog(dialog:Dialog):Dialog {
        addControl(dialog);

        __dialog = dialog;
        __dialog.x = Math.round(__container.width / 2) - (__dialog.width / 2);
        __dialog.y = Math.round(__container.height / 2) - (__dialog.height / 2);

        return __dialog;
    }

    private function get_markedControl():Control {
        return __markedControl;
    }

    private function set_markedControl(control:Control):Control {
        __markedControl.onMouseLeave();
        __markedControl = control;

        return control;
    }

    private function get_focusedControl():Control {
        return __focusedControl;
    }

    private function set_focusedControl(control:Control):Control {
        __focusedControl.onFocusLost();
        __focusedControl = control;

        return control;
    }

    private function get_toolstripmenu():Toolstripmenu {
        return __toolstripmenu;
    }

    private function get_mouseX():Int {
        return parent.app.input.mouse.x;
    }

    private function get_mouseY():Int {
        return parent.app.input.mouse.y;
    }

    private function get_leftClick():Bool {
        return parent.app.input.mouse.released(0); // ** TODO: Fix this.
    }

    private function get_width():Float {
        return __container.width;
    }

    private function get_height():Float {
        return __container.height;
    }
}

private class RootContainer extends Container<Control> {

    public function new(width:Float, height:Float) {

        super(width, height, 0, 0);

        __type = "canvas";
    }

    override function init() {

        super.init();
    }

    public function addControl(control:Control):Control {
        
        return __addControl(control);
    }

    public function removeControl(control:Control):Void {
        
        return __removeControl(control);
    }
}