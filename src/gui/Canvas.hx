package gui;

import Entity;
import State;
import Renderer;
import display.TileBatch;
import display.BitmapFont;
import haxe.Json;

/**
 * Canvas - Simplified UI container for GUI elements
 * 
 * Manages UI rendering with TileBatch for UI elements and BitmapFont for text
 */
class Canvas extends Entity {
    
    // Public properties
    public var tilemap:TileBatch;
    public var font:BitmapFont;
    public var width:Float = 640;
    public var height:Float = 480;
    public var markedControl(get, set):Control; 
    public var focusedControl(get, set):Control;
    //public var dialog(get, set):Dialog;
    
    // UI element texture regions
    public var sets:Map<String, Int> = new Map();
    
    // Parent state reference
    public var parentState:State;
    
    // Mouse state
    public var mouseX(get, null):Float;
    public var mouseY(get, null):Float;
    public var leftClick(get, null):Bool;

    private var __container:RootContainer;
    //private var __dialog:Dialog;
    private var __markedControl:Control;
    private var __focusedControl:Control;
    
    /**
     * Create a new Canvas
     * @param parentState The parent state
     * @param width Canvas width
     * @param height Canvas height
     */
    public function new(parentState:State, width:Float = 640, height:Float = 480) {
        super("canvas");
        
        this.parentState = parentState;
        this.width = width;
        this.height = height;

        __container = new RootContainer(640, 480);
        @:privateAccess __container.____canvas = this;
        __markedControl = __container;
        __focusedControl = __container;
        //dialog = new Dialog('Intro', 256, 256);


        trace("Canvas: Created with size " + width + "x" + height);
    }
    
    /**
     * Initialize the canvas with UI texture and font
     * @param tileBatch TileBatch for UI elements
     * @param font BitmapFont for text rendering
     */
    public function initializeGraphics(tileBatch:TileBatch, font:BitmapFont):Void {
        this.tilemap = tileBatch;
        this.font = font;
        
        trace("Canvas: Graphics initialized");
    }
    
    /**
     * Import texture atlas regions for UI elements
     * @param jsonData JSON string containing region definitions
     */
    public function importSets(jsonData:String):Void {
        var data:Dynamic = Json.parse(jsonData);
        
        if (tilemap == null) {
            trace("Canvas: Warning - TileBatch not initialized, cannot import sets");
            return;
        }
        
        var count = 0;
        for (i in 0...data.regions.length) {
            var region = data.regions[i];
            var name:String = region.name;
            var dim:Array<Int> = region.dim;
            
            // Define region in tileBatch
            var regionId = tilemap.defineRegion(dim[0], dim[1], dim[2], dim[3]);
            sets.set(name, regionId);
            count++;
        }
        
        trace("Canvas: Imported " + count + " UI texture regions");
    }

    public function addControl(control:Control):Control {
        return __container.addControl(control);
    }

    public function removeControl(control:Control):Void {
        return __container.removeControl(control);
    }

    
    /**
     * Get a UI texture region ID by name
     * @param name Region name
     * @return Region ID, or -1 if not found
     */
    public function getSet(name:String):Int {
        var regionId = sets.get(name);
        return regionId != null ? regionId : -1;
    }
    
    override public function update(deltaTime:Float):Void {
        // if (__dialog.visible) {
        //     __dialog.update();
        //     return;
        // }

        __container.update();
    }
    
    public function resize(width:Int, height:Int) {
        this.width = width;
        this.height = height;

        __container.resize(width, height);
    }

    // Mouse getters
    private function get_mouseX():Float {
        return parentState.app.input.mouse.x;
    }
    
    private function get_mouseY():Float {
        return parentState.app.input.mouse.y;
    }
    
    private function get_leftClick():Bool {
        return parentState.app.input.mouse.released(0);
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
