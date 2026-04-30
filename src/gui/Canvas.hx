package gui;

import display.TileBatch.AtlasRegion;
import display.ManagedTileBatch;
import display.IFontSource;
import display.Tile;
import Entity;
import State;
import Renderer;
import loaders.FontData;
import loaders.FontData.FontChar;
import Texture;
import haxe.Json;

/**
 * Canvas - Unified UI container for GUI elements
 * 
 * Manages UI rendering with a single UIBatch bound to two textures:
 *   unit 0 — sprite atlas (panels, buttons, icons)
 *   unit 1 — font atlas  (glyph tiles via private UIFont)
 * Both graphic and text tiles are submitted to the same batch so draw order
 * exactly matches the control tree, eliminating the text-over-graphics issue.
 */
class Canvas extends Entity {
    
    // Public properties
    public var tilemap:ManagedTileBatch;
    public var font(get, null):IFontSource;
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
    private var __font:IFontSource;
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
     * Initialize the canvas with a unified UI batch and font.
     *
     * The "ui" shader must be pre-registered in the renderer before this call:
     *   renderer.createProgramInfo("ui", null, fragSource);
     *
     * @param renderer      Active Renderer instance
     * @param spriteTexture Sprite/icon atlas — bound to texture unit 0
     * @param fontTexture   Bitmap font atlas  — bound to texture unit 1
     * @param fontData      Parsed font metrics (from FontLoader)
     */
    public function initializeGraphics(renderer:Renderer, spriteTexture:Texture, fontTexture:Texture, fontData:FontData):Void {
        var uiBatch = new UIBatch(renderer, spriteTexture, fontTexture);
        tilemap = uiBatch;
        __font  = new UIFont(uiBatch, fontData);

        trace("Canvas: Graphics initialized (UIBatch, dual-texture ui shader)");
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

    // Getters
    private function get_font():IFontSource {
        return __font;
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

// =============================================================================
// UIBatch — unified 6-float-per-vertex tile batch for the UI shader.
//
// Extends ManagedTileBatch without touching the primitive TileBatch or Tile
// classes. The extra float per vertex carries a texture-unit selector:
//   0.0 → uGraphics  (sprite atlas, unit 0)
//   1.0 → uFont      (bitmap font atlas, unit 1)
//
// Font regions are registered with UV coordinates relative to the font texture
// (not the sprite atlas) via defineFontRegion(). Font tiles are added via
// addFontTile() which records texIndex = 1.0 in __texIndices.
// =============================================================================

@:shader("ui")
private class UIBatch extends ManagedTileBatch {

    private static inline var MAX_TILES_UI:Int = 1000;

    // Maps Tile reference → texIndex (only entries with value 1.0 are stored)
    private var __texIndices:Map<Tile, Float> = new Map();

    // Font texture dimensions, used to compute correct UVs for glyph regions
    private var __fontTexWidth:Int  = 1;
    private var __fontTexHeight:Int = 1;

    public function new(renderer:Renderer, spriteTexture:Texture, fontTexture:Texture) {
        super(renderer, null, spriteTexture);   // @:shader("ui") resolves ProgramInfo
        addTexture(fontTexture);                // font atlas → texture unit 1
        __fontTexWidth  = fontTexture.width;
        __fontTexHeight = fontTexture.height;
    }

    /**
     * Define an atlas region whose UVs are relative to the font texture (unit 1).
     * Calls the parent defineRegion() to allocate an ID, then corrects the UV
     * coordinates using the font texture dimensions.
     */
    public function defineFontRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        var regionId = defineRegion(atlasX, atlasY, atlasWidth, atlasHeight);
        // Fix UVs: defineRegion used textures[0] (sprite atlas) dimensions, recompute.
        var region = atlasRegions.get(regionId);
        region.u1 = atlasX                     / __fontTexWidth;
        region.v1 = atlasY                     / __fontTexHeight;
        region.u2 = (atlasX + atlasWidth)      / __fontTexWidth;
        region.v2 = (atlasY + atlasHeight)     / __fontTexHeight;
        return regionId;
    }

    /** Add a tile that will sample the font atlas (texIndex = 1.0). */
    public function addFontTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        var tileId = addTile(x, y, width, height, regionId);
        var tile   = getTile(tileId);
        if (tile != null) __texIndices.set(tile, 1.0);
        return tileId;
    }

    override public function removeTile(tileId:Int):Bool {
        var tile = getTile(tileId);
        if (tile != null) __texIndices.remove(tile);
        return super.removeTile(tileId);
    }

    override public function removeTileInstance(tile:Tile):Bool {
        __texIndices.remove(tile);
        return super.removeTileInstance(tile);
    }

    /** Build one tile into the vertex buffer — 6 floats per vertex (x,y,z,u,v,ti). */
    override public function buildTile(tile:Tile):Void {
        var region = atlasRegions.get(tile.regionId);
        if (region == null) {
            region = new AtlasRegion();
            region.u1 = -1.0; region.v1 = -1.0;
            region.u2 = -1.0; region.v2 = -1.0;
        }

        // V flip to match TileBatch.generateTileVertices convention
        var uv1 = region.v2;
        var uv2 = region.v1;

        var tx = tile.x + tile.offsetX;
        var ty = tile.y + tile.offsetY;
        var hw = tile.width  * 0.5;
        var hh = tile.height * 0.5;
        var cx = tx + hw;
        var cy = ty + hh;

        var cosA = 1.0;
        var sinA = 0.0;
        if (tile.rotation != 0.0) {
            var rad = tile.rotation * Math.PI / 180.0;
            cosA = Math.cos(rad);
            sinA = Math.sin(rad);
        }

        var ti:Float = __texIndices.exists(tile) ? 1.0 : 0.0;

        // Top-left
        vertices.push(-hw * cosA - hh * sinA + cx); vertices.push(-hw * sinA + hh * cosA + cy); vertices.push(0.0); vertices.push(region.u1); vertices.push(uv1); vertices.push(ti);
        // Top-right
        vertices.push( hw * cosA - hh * sinA + cx); vertices.push( hw * sinA + hh * cosA + cy); vertices.push(0.0); vertices.push(region.u2); vertices.push(uv1); vertices.push(ti);
        // Bottom-right
        vertices.push( hw * cosA + hh * sinA + cx); vertices.push( hw * sinA - hh * cosA + cy); vertices.push(0.0); vertices.push(region.u2); vertices.push(uv2); vertices.push(ti);
        // Bottom-left
        vertices.push(-hw * cosA + hh * sinA + cx); vertices.push(-hw * sinA - hh * cosA + cy); vertices.push(0.0); vertices.push(region.u1); vertices.push(uv2); vertices.push(ti);

        __verticesToRender += 4;
        __indicesToRender  += 6;
    }

    /**
     * Override updateBuffers to use the 6-float orphan size and to call our
     * overridden buildTile instead of the base 5-float version.
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!active || textures[0] == null) return;

        @:privateAccess
        for (tile in tiles) {
            if (tile.visible) buildTile(tile);
        }

        if (vbo != 0 && vertices.length > 0) {
            renderer.orphanAndUploadData(this, MAX_TILES_UI * 4 * 6 * 4);
        }

        needsBufferUpdate = false;
    }
}

// =============================================================================
// UIFont — private font proxy that submits glyph tiles into UIBatch with
// texIndex = 1.0. Implements IFontSource so Text can use it transparently.
//
// Never instantiated outside Canvas. Character regions are registered once
// in the constructor using UIBatch.defineFontRegion() so UVs are computed
// relative to the font texture, not the sprite atlas.
// =============================================================================

private class UIFont implements IFontSource {

    public var fontData:FontData;

    private var __batch:UIBatch;
    private var __charToRegion:Map<Int, Int> = new Map();

    public function new(batch:UIBatch, fontData:FontData) {
        __batch        = batch;
        this.fontData  = fontData;
        __registerCharRegions();
    }

    private function __registerCharRegions():Void {
        for (charCode in fontData.chars.keys()) {
            var c = fontData.chars.get(charCode);
            __charToRegion.set(charCode,
                __batch.defineFontRegion(c.x, c.y, c.width, c.height));
        }
    }

    public function getRegionForChar(charCode:Int):Int {
        var r = __charToRegion.get(charCode);
        return r != null ? r : -1;
    }

    public function getCharData(charCode:Int):FontChar {
        return fontData.chars.get(charCode);
    }

    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        return __batch.addFontTile(x, y, width, height, regionId);
    }

    public function removeTile(tileId:Int):Bool {
        return __batch.removeTile(tileId);
    }

    public function getTile(tileId:Int):Tile {
        return __batch.getTile(tileId);
    }

    public function measureTextWidth(text:String):Float {
        var maxW:Float = 0;
        var cur:Float  = 0;
        for (i in 0...text.length) {
            var code = text.charCodeAt(i);
            if (code == 10) { if (cur > maxW) maxW = cur; cur = 0; continue; }
            var c = fontData.chars.get(code);
            if (c != null) cur += c.xadvance;
        }
        return cur > maxW ? cur : maxW;
    }

    public function measureTextHeight(text:String):Float {
        var lines = 1;
        for (i in 0...text.length) if (text.charCodeAt(i) == 10) lines++;
        return lines * fontData.lineHeight;
    }

    public function markDirty():Void { __batch.needsBufferUpdate = true; }
}

// =============================================================================

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
