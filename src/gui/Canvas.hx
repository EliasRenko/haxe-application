package gui;

import Entity;
import State;
import Renderer;
import Input;
import display.TileBatchFast;
import display.Text;
import math.Matrix;
import gui.Container;
import gui.Control;

/**
 * Canvas - Main UI manager for haxe-application
 * 
 * Manages UI controls, input handling, focus, and rendering
 * Uses TileBatchFast for UI element rendering and Text for labels
 * 
 * Features:
 * - Control hierarchy management via root container
 * - Mouse input handling and propagation
 * - Focus management for interactive controls
 * - Dialog system for modal popups
 * - Texture atlas loading for UI sprites
 * - Integration with Entity/State system
 */
class Canvas extends Entity {
    
    // ** Public Properties

    /** Active dialog (null if no dialog shown) */
    public var dialog(get, set):Dialog;

    /** Control currently under mouse cursor */
    public var markedControl(get, set):Control;

    /** Control that has input focus */
    public var focusedControl(get, set):Control;

    /** Mouse X position in screen space */
    public var mouseX(get, null):Float;
    
    /** Mouse Y position in screen space */
    public var mouseY(get, null):Float;
    
    /** True if left mouse button was released this frame */
    public var leftClick(get, null):Bool;

    /** Width of canvas/viewport */
    public var width(get, null):Float;

    /** Height of canvas/viewport */
    public var height(get, null):Float;

    /** TileBatchFast for rendering UI elements */
    public var tileBatchFast:TileBatchFast;

    /** Text display for labels and text */
    public var textDisplay:Text;

    // ** Private State

    /** Root container holding all top-level controls */
    private var __container:RootContainer;

    /** Active dialog reference */
    private var __dialog:Dialog;

    /** Control under mouse cursor */
    private var __markedControl:Control;

    /** Control with input focus */
    private var __focusedControl:Control;

    /** Atlas region name to region ID mapping */
    private var __regionMap:Map<String, Int> = new Map();

    /** Canvas dimensions */
    private var __width:Float = 0;
    private var __height:Float = 0;

    /** Parent state reference */
    private var __parentState:State;

    /**
     * Create a new Canvas UI manager
     * @param parentState The state this canvas belongs to
     * @param width Canvas width (default: window width)
     * @param height Canvas height (default: window height)
     */
    public function new(parentState:State, width:Float = 0, height:Float = 0) {
        super("canvas");

        __parentState = parentState;
        __width = width > 0 ? width : parentState.app.WINDOW_WIDTH;
        __height = height > 0 ? height : parentState.app.WINDOW_HEIGHT;

        // Create root container
        __container = new RootContainer(__width, __height);
        @:privateAccess __container.____canvas = this;

        // Initialize marked and focused to root container
        __markedControl = __container;
        __focusedControl = __container;

        trace("Canvas created: " + __width + "x" + __height);
    }

    /**
     * Initialize Canvas - called when added to State
     * Sets up TileBatchFast for UI rendering
     */
    public function init():Void {
        if (state == null) {
            trace("Warning: Canvas.init() called but Canvas has no state reference");
            return;
        }

        var renderer = state.app.getRenderer();

        // Create shader program for UI rendering
        var vertShader = state.app.resources.getText("shaders/textured.vert");
        var fragShader = state.app.resources.getText("shaders/textured.frag");
        var programInfo = renderer.createProgramInfo("Canvas_UI", vertShader, fragShader);

        if (programInfo == null) {
            trace("Error: Failed to create Canvas shader program");
            return;
        }

        // Create TileBatchFast for UI elements (will set texture via loadUIAtlas)
        tileBatchFast = new TileBatchFast(programInfo, null);
        tileBatchFast.x = 0;
        tileBatchFast.y = 0;
        tileBatchFast.z = 0;

        trace("Canvas initialized with TileBatchFast");
    }

    /**
     * Load UI texture atlas and define regions
     * @param atlasTexturePath Path to atlas texture (e.g., "textures/gui.tga")
     * @param metadataPath Path to atlas metadata JSON (e.g., "text/gui.json")
     */
    public function loadUIAtlas(atlasTexturePath:String, metadataPath:String):Void {
        if (tileBatchFast == null) {
            trace("Error: Canvas not initialized, call init() first");
            return;
        }

        var renderer = state.app.getRenderer();

        // Load and upload atlas texture
        var textureData = state.app.resources.getTexture(atlasTexturePath);
        if (textureData == null) {
            trace("Error: Failed to load UI atlas texture: " + atlasTexturePath);
            return;
        }

        var texture = renderer.uploadTexture(textureData);
        tileBatchFast.atlasTexture = texture;

        trace("Canvas: Loaded UI atlas texture " + texture.width + "x" + texture.height);

        // Initialize TileBatchFast now that we have a texture
        if (!tileBatchFast.initialized) {
            tileBatchFast.init(renderer);
            trace("Canvas: TileBatchFast initialized");
        }

        // Load and parse atlas metadata
        var jsonText = state.app.resources.getText(metadataPath);
        if (jsonText == null) {
            trace("Error: Failed to load UI atlas metadata: " + metadataPath);
            return;
        }

        var atlasData:Dynamic = haxe.Json.parse(jsonText);

        // Define regions in TileBatchFast
        if (atlasData.regions != null) {
            for (region in (atlasData.regions:Array<Dynamic>)) {
                var name:String = region.name;
                var x:Int = region.x != null ? region.x : region.dim[0];
                var y:Int = region.y != null ? region.y : region.dim[1];
                var width:Int = region.width != null ? region.width : region.dim[2];
                var height:Int = region.height != null ? region.height : region.dim[3];

                var regionId = tileBatchFast.defineRegion(x, y, width, height);
                __regionMap.set(name, regionId);

                trace("Canvas: Defined region '" + name + "' -> ID " + regionId + " (" + x + "," + y + "," + width + "," + height + ")");
            }
        }

        // Count regions in map
        var regionCount = 0;
        for (key in __regionMap.keys()) {
            regionCount++;
        }

        trace("Canvas: UI atlas loaded with " + regionCount + " regions");
    }

    /**
     * Get region ID by name
     * @param name Region name from atlas metadata
     * @return Region ID, or -1 if not found
     */
    public function getRegionId(name:String):Int {
        var id = __regionMap.get(name);
        return id != null ? id : -1;
    }

    /**
     * Add a control to the canvas
     * @param control Control to add
     * @return The added control
     */
    public function addControl(control:Control):Control {
        return __container.addControl(control);
    }

    /**
     * Remove a control from the canvas
     * @param control Control to remove
     */
    public function removeControl(control:Control):Void {
        __container.removeControl(control);
    }

    /**
     * Update canvas and all controls
     * Handles input, focus management, and control updates
     */
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        // Update TileBatchFast buffers if needed
        if (tileBatchFast != null && tileBatchFast.initialized && tileBatchFast.needsBufferUpdate) {
            tileBatchFast.updateBuffers(state.app.getRenderer());
        }

        // Update dialog if visible, otherwise update root container
        if (__dialog != null && __dialog.visible) {
            __dialog.update();
        } else {
            __container.update();
        }

        // Handle focus changes
        if (__markedControl != __focusedControl) {
            if (__focusedControl != null) {
                __focusedControl.onFocusLost();
            }
            __focusedControl = __markedControl;
        }

        // Reset marked control for next frame
        __markedControl = null;
    }

    /**
     * Render canvas UI
     * Renders TileBatchFast and Text displays through the renderer
     */
    override public function render(renderer:Renderer, viewProjectionMatrix:Matrix):Void {
        super.render(renderer, viewProjectionMatrix);

        // Render UI elements via TileBatchFast through the renderer
        if (tileBatchFast != null && tileBatchFast.initialized) {
            renderer.renderDisplayObject(tileBatchFast, viewProjectionMatrix);
        }

        // Render text via Text display through the renderer
        if (textDisplay != null) {
            renderer.renderDisplayObject(textDisplay, viewProjectionMatrix);
        }
    }

    /**
     * Clean up canvas resources
     */
    override public function cleanup(renderer:Renderer):Void {
        if (tileBatchFast != null && tileBatchFast.initialized) {
            // Clean up TileBatchFast buffers
            // TODO: Add cleanup method to TileBatchFast if needed
        }

        __container.release();

        super.cleanup(renderer);
    }

    // ** Getters and Setters

    private function get_dialog():Dialog {
        return __dialog;
    }

    private function set_dialog(dialog:Dialog):Dialog {
        if (dialog != null) {
            addControl(dialog);

            __dialog = dialog;

            // Center dialog on canvas
            __dialog.x = Math.round(__width / 2 - __dialog.width / 2);
            __dialog.y = Math.round(__height / 2 - __dialog.height / 2);
        } else {
            __dialog = dialog;
        }

        return __dialog;
    }

    private function get_markedControl():Control {
        return __markedControl;
    }

    private function set_markedControl(control:Control):Control {
        if (__markedControl != null && __markedControl != control) {
            __markedControl.onMouseLeave();
        }
        __markedControl = control;
        return control;
    }

    private function get_focusedControl():Control {
        return __focusedControl;
    }

    private function set_focusedControl(control:Control):Control {
        if (__focusedControl != null && __focusedControl != control) {
            __focusedControl.onFocusLost();
        }
        __focusedControl = control;
        return control;
    }

    private function get_mouseX():Float {
        return state.app.input.mouse.x;
    }

    private function get_mouseY():Float {
        return state.app.input.mouse.y;
    }

    private function get_leftClick():Bool {
        return state.app.input.mouse.released(1); // Button 1 = left mouse
    }

    private function get_width():Float {
        return __width;
    }

    private function get_height():Float {
        return __height;
    }
}

/**
 * RootContainer - Private container class for Canvas top-level controls
 * Wraps Container<Control> and provides public addControl/removeControl
 */
private class RootContainer extends Container<Control> {

    public function new(width:Float, height:Float) {
        super(width, height, 0, 0);
        __type = "canvas_root";
    }

    override function init():Void {
        super.init();
    }

    /**
     * Public method to add control (exposes private __addControl)
     */
    override public function addControl(control:Control):Control {
        return super.addControl(control);
    }

    /**
     * Public method to remove control (exposes private __removeControl)
     */
    override public function removeControl(control:Control):Void {
        super.removeControl(control);
    }
}
