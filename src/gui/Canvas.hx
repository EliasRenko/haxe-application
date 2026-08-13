package gui;

import display.TileBatch.AtlasRegion;
import display.ManagedTileBatch;
import display.IFontSource;
import display.Image;
import display.Tile;
import Entity;
import State;
import Renderer;
import loaders.FontData;
import loaders.FontData.FontChar;
import math.Matrix;
import Texture;
import gui.ImageHook;
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
    public var mouseScrollY(get, null):Float;

    // Renderer reference (stored at initializeGraphics time)
    public var renderer(get, null):Renderer;

    private var __container:RootContainer;
    private var __fontFaces:Array<UIFontFace> = [];
    private var __uiBatch:UIBatch;
    private var __markedControl:Control;
    private var __focusedControl:Control;
    private var __clipRectCounter:Int = 0;
    private var __clipRectHandles:Map<Int, ClipRect> = new Map();
    private var __renderer:Renderer;
    private var __nextGroupTag:Int = 1;
    private var __controlGroupTags:Map<Control, Int> = new Map();

    // ── Focus stack ───────────────────────────────────────────────────────────
    // The top entry is the only container that receives mouse input each frame.
    // Modal entries (Windows) block input behind them unconditionally.
    // Non-modal entries (Dropdown popups) auto-dismiss on an outside click.
    private var __focusStack:Array<{control:Control, modal:Bool}> = [];
    // Prevents the auto-dismiss logic from firing on the same frame a non-modal
    // overlay was pushed (avoids open→dismiss in one tick).
    private var __overlayAddedThisFrame:Bool = false;

    // Flat list of controls added via pushOverlay — their tiles are added to the
    // batch AFTER all normal controls, so they always render on top.
    private var __overlayControls:Array<Control> = [];
    
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
        __renderer = renderer;
        __uiBatch = new UIBatch(renderer, spriteTexture, fontTexture);
        tilemap = __uiBatch;
        __fontFaces = [new UIFontFace(__uiBatch, fontData)];

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
            
            // Define region in tileBatch
            var regionId = tilemap.defineRegion(region.x, region.y, region.width, region.height);
            sets.set(name, regionId);
            count++;
        }
        
        trace("Canvas: Imported " + count + " UI texture regions");
    }

    public function addControl(control:Control):Control {
        if (Std.isOfType(control, Window) && __uiBatch != null) {
            var tag = __nextGroupTag++;
            __controlGroupTags.set(control, tag);
            __uiBatch.pendingGroupTag = tag;
            var result = __container.addControl(control);
            __uiBatch.pendingGroupTag = 0;
            return result;
        }
        return __container.addControl(control);
    }

    public function removeControl(control:Control):Void {
        __controlGroupTags.remove(control);
        __container.removeControl(control);
    }

    // ── Focus stack API ───────────────────────────────────────────────────────

    /**
     * Push a non-modal focus entry (e.g. a Dropdown popup).
     * Auto-dismissed when the user clicks outside it.
     */
    public function pushFocus(control:Control):Void {
        __focusStack.push({control: control, modal: false});
        __overlayAddedThisFrame = true;
    }

    /**
     * Push a modal focus entry (e.g. a Window).
     * Blocks all input behind it; must be explicitly dismissed.
     */
    public function pushModalFocus(control:Control):Void {
        __focusStack.push({control: control, modal: true});
    }

    /**
     * Remove a control from the focus stack (by reference, any position).
     */
    public function popFocus(control:Control):Void {
        for (i in 0...__focusStack.length) {
            if (__focusStack[i].control == control) {
                __focusStack.splice(i, 1);
                return;
            }
        }
    }

    // ── Z-order API ───────────────────────────────────────────────────────────

    /**
     * Begin attributing newly added tiles/hooks to the group tag of [control].
     * Called by Window.addControl so that content tiles share the window's tag.
     */
    public function beginGroupTag(control:Control):Void {
        if (__uiBatch == null) return;
        var tag = __controlGroupTags.get(control);
        if (tag != null) __uiBatch.pendingGroupTag = tag;
    }

    /** Clear the pending group tag (called by Window.addControl after child init). */
    public function endGroupTag():Void {
        if (__uiBatch != null) __uiBatch.pendingGroupTag = 0;
    }

    /**
     * Move all render list entries belonging to [control]'s group tag to the
     * end of the render list so the control renders on top of everything else.
     */
    public function raiseControlToTop(control:Control):Void {
        var tag = __controlGroupTags.get(control);
        if (tag != null) __uiBatch.raiseGroupToTop(tag);
    }

    // ── ImageView hook API ────────────────────────────────────────────────────

    /**
     * Register an ImageHook into the UIBatch render list at the current
     * insertion position.  Called by ImageView.init().
     */
    public function registerImageHook(hook:ImageHook):Void {
        __uiBatch.addImageHook(hook);
    }

    /**
     * Remove an ImageHook from the UIBatch render list.
     * Called by ImageView.release().
     */
    public function unregisterImageHook(hook:ImageHook):Void {
        __uiBatch.removeImageHook(hook);
    }

    // ── Overlay API ───────────────────────────────────────────────────────────

    /**
     * Add a control to the overlay layer.
     * Its tiles are initialised here, so they land at the END of the batch
     * and therefore render on top of everything else.
     */
    public function pushOverlay(control:Control):Void {
        @:privateAccess control.____canvas  = this;
        @:privateAccess control.____offsetX = 0.0;
        @:privateAccess control.____offsetY = 0.0;
        @:privateAccess control.____parent  = null;
        control.init();
        __overlayControls.push(control);
    }

    /**
     * Remove a control from the overlay layer and release its tiles.
     * Safe to call even if the control was already removed.
     */
    public function removeOverlay(control:Control):Void {
        if (__overlayControls.remove(control)) {
            control.release();
        }
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
    
    /**
     * Render the canvas.  Replaces the old DisplayEntity(canvas.tilemap) pattern.
     *
     * When no ImageViews are present: single UIBatch draw call (identical to
     * the previous behaviour).
     *
     * When ImageViews are present: the UIBatch render list is walked in
     * insertion order.  Accumulated tile segments are flushed before each
     * image hook, producing N+1 draw calls for N ImageViews.
     */
    override public function render(renderer:Renderer, viewProjectionMatrix:Matrix, cameraDirty:Bool):Void {
        if (!active || !visible || __uiBatch == null) return;

        var renderList = __uiBatch.getRenderList();

        // Fast path: no image hooks — single draw call.
        var hasHooks = false;
        for (item in renderList) {
            if (!item.isTile) { hasHooks = true; break; }
        }

        if (!hasHooks) {
            __uiBatch.segmentTiles = null;
            renderer.renderDisplayObject(__uiBatch, viewProjectionMatrix, cameraDirty);
            return;
        }

        // Segmented path: flush tile segments around each image hook.
        var segment:Array<Tile> = [];
        for (item in renderList) {
            if (item.isTile) {
                if (item.tile.visible) segment.push(item.tile);
            } else {
                // Flush accumulated tile segment.
                if (segment.length > 0) {
                    __uiBatch.segmentTiles = segment;
                    renderer.renderDisplayObject(__uiBatch, viewProjectionMatrix, cameraDirty);
                    __uiBatch.segmentTiles = null;
                    segment = [];
                }
                // Draw the image.
                var hook = item.hook;
                if (hook.visible && hook.displayImage != null) {
                    renderer.renderDisplayObject(hook.displayImage, viewProjectionMatrix, cameraDirty);
                }
            }
        }
        // Flush any remaining tiles after the last hook.
        if (segment.length > 0) {
            __uiBatch.segmentTiles = segment;
            renderer.renderDisplayObject(__uiBatch, viewProjectionMatrix, cameraDirty);
            __uiBatch.segmentTiles = null;
        }
    }

    override public function update(deltaTime:Float):Void {
        __overlayAddedThisFrame = false;

        // Click-to-raise: when the user clicks somewhere other than the topmost
        // window, check if another (background) window was hit and bring it forward.
        if (__focusStack.length > 0 && parentState.app.input.mouse.pressed(0)) {
            var topEntry = __focusStack[__focusStack.length - 1];
            if (!topEntry.control.hitTest()) {
                var i = __focusStack.length - 2;
                while (i >= 0) {
                    var e = __focusStack[i];
                    if (e.modal && e.control.hitTest()) {
                        __focusStack.splice(i, 1);
                        __focusStack.push(e);
                        raiseControlToTop(e.control);
                        break;
                    }
                    i--;
                }
            }
        }

        // Always update the full control tree.
        // Modal windows (Window) live inside __container and receive their update
        // naturally via Container's hit-test loop, so they never block the toolstrip.
        __container.update();

        // Non-modal overlay controls (e.g. Dropdown popups) are NOT in __container;
        // they need an explicit update and must be dismissed on outside click.
        if (__focusStack.length > 0) {
            var entry = __focusStack[__focusStack.length - 1];
            if (!entry.modal) {
                if (entry.control.hitTest()) {
                    entry.control.update();
                } else if (leftClick && !__overlayAddedThisFrame) {
                    var ctrl = entry.control;
                    popFocus(ctrl);
                    removeOverlay(ctrl);
                }
            }
        }
    }
    
    public function resize(width:Int, height:Int) {
        this.width = width;
        this.height = height;

        __container.resize(width, height);
    }

    // Getters
    private function get_font():IFontSource {
        return __fontFaces[0];
    }

    /**
     * Return the IFontSource for the given face index.
     * Face 0 is always the font passed to initializeGraphics.
     * Faces 1..n are added via addFontFace().
     */
    public function getFace(index:Int):IFontSource {
        if (index < 0 || index >= __fontFaces.length)
            throw 'Canvas.getFace: index $index out of range (${__fontFaces.length} face(s) registered)';
        return __fontFaces[index];
    }

    /**
     * Register an additional font face that shares the same atlas texture.
     * The fontData must describe glyphs baked into the same texture that was
     * passed to initializeGraphics() — as produced by FontBaker.bakeMultiple().
     *
     * @return  The face index to pass to getFace().
     */
    public function addFontFace(fontData:FontData):Int {
        if (__uiBatch == null)
            throw "Canvas.addFontFace: call initializeGraphics first";
        __fontFaces.push(new UIFontFace(__uiBatch, fontData));
        return __fontFaces.length - 1;
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

    private function get_mouseScrollY():Float {
        return parentState.app.input.mouse.scrollY;
    }

    private function get_renderer():Renderer {
        return __renderer;
    }

    // ── Clip rect API (used by ScrollableContainer) ──────────────────────────

    public function createClipRect(x:Float, y:Float, w:Float, h:Float):Int {
        var id = __clipRectCounter++;
        __clipRectHandles.set(id, new ClipRect(x, y, x + w, y + h));
        return id;
    }

    public function activateClipRect(handle:Int):Void {
        __uiBatch.setPendingClipRect(__clipRectHandles.get(handle));
    }

    public function deactivateClipRect():Void {
        __uiBatch.setPendingClipRect(null);
    }

    /**
     * Set the default multiply tint applied to all graphic tiles.
     * Font tiles are always rendered white regardless of this setting.
     * @param r  Red   (0.0–1.0)
     * @param g  Green (0.0–1.0)
     * @param b  Blue  (0.0–1.0)
     * @param a  Alpha (0.0–1.0), default 1.0
     */
    public function setTint(r:Float, g:Float, b:Float, a:Float = 1.0):Void {
        __uiBatch.defaultColor = [r, g, b, a];
    }

    public function updateClipRect(handle:Int, x:Float, y:Float, w:Float, h:Float):Void {
        var cr = __clipRectHandles.get(handle);
        if (cr != null) cr.set(x, y, x + w, y + h);
    }

    public function destroyClipRect(handle:Int):Void {
        __clipRectHandles.remove(handle);
    }

    /**
     * Pin a tile to white (1,1,1,1), exempting it from the canvas tint.
     * Call this after addTileInstance for tiles that should never be tinted.
     */
    public function setTileNoTint(tile:Tile):Void {
        if (__uiBatch != null) __uiBatch.setTileColor(tile, 1.0, 1.0, 1.0, 1.0);
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
// UIBatch — unified 10-float-per-vertex tile batch for the UI shader.
//
// Extends ManagedTileBatch without touching the primitive TileBatch or Tile
// classes. Per-vertex layout: x y z u v ti r g b a
//   ti:    0.0 → uGraphics (sprite atlas, unit 0)
//          1.0 → uFont    (bitmap font atlas, unit 1)
//   r,g,b,a: multiply tint — font tiles are always (1,1,1,1); graphic tiles
//            use __tileColors[tile] if set, otherwise defaultColor.
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

    // Maps Tile reference → ClipRect (only clipped tiles have entries)
    private var __clipRects:Map<Tile, ClipRect> = new Map();

    // Per-tile RGBA multiply color. Missing entries use defaultColor.
    private var __tileColors:Map<Tile, Array<Float>> = new Map();

    // Default multiply tint applied to all graphic tiles without an explicit color.
    // Font tiles always use (1,1,1,1) regardless of this value.
    public var defaultColor:Array<Float> = [1.0, 1.0, 1.0, 1.0];

    // ── Render list ───────────────────────────────────────────────────────────
    // Ordered list of all items (tiles + image hooks) in insertion order.
    // Canvas.render() walks this to interleave UIBatch segments and Image draws.
    private var __renderList:Array<{isTile:Bool, tile:Tile, hook:ImageHook}> = [];

    // When non-null, updateBuffers() builds only this subset of tiles.
    // Canvas.render() sets/clears this around each renderDisplayObject call.
    public var segmentTiles:Array<Tile> = null;

    // Group tagging for Z-order: tiles/hooks added while pendingGroupTag != 0 are
    // recorded so raiseGroupToTop() can move them to the end of the render list.
    public var pendingGroupTag:Int = 0;
    private var __tileTags:Map<Tile, Int> = new Map();
    private var __hookTags:Map<ImageHook, Int> = new Map();

    private static final __WHITE:Array<Float> = [1.0, 1.0, 1.0, 1.0];

    // Clip rect applied to the next addTile / addTileInstance call (null = unclipped)
    private var __pendingClipRect:ClipRect = null;

    // Font texture dimensions, used to compute correct UVs for glyph regions
    private var __fontTexWidth:Int  = 1;
    private var __fontTexHeight:Int = 1;

    public function new(renderer:Renderer, spriteTexture:Texture, fontTexture:Texture) {
        super(renderer, spriteTexture);   // @:shader("ui") resolves ProgramInfo
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

    /** Set the clip rect that will be assigned to the next tile(s) added. */
    public function setPendingClipRect(clip:ClipRect):Void {
        __pendingClipRect = clip;
    }

    override public function addTile(x:Float, y:Float, w:Float, h:Float, regionId:Int):Int {
        var tileId = super.addTile(x, y, w, h, regionId);
        if (tileId != -1) {
            var tile = getTile(tileId);
            if (tile != null) {
                __renderList.push({isTile: true, tile: tile, hook: null});
                if (__pendingClipRect != null) __clipRects.set(tile, __pendingClipRect);
                if (pendingGroupTag > 0) __tileTags.set(tile, pendingGroupTag);
            }
        }
        return tileId;
    }

    override public function addTileInstance(tile:Tile):Void {
        super.addTileInstance(tile);
        __renderList.push({isTile: true, tile: tile, hook: null});
        if (__pendingClipRect != null) __clipRects.set(tile, __pendingClipRect);
        if (pendingGroupTag > 0) __tileTags.set(tile, pendingGroupTag);
    }

    /** Add a tile that will sample the font atlas (texIndex = 1.0). */
    public function addFontTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        var tileId = addTile(x, y, width, height, regionId);
        var tile   = getTile(tileId);
        if (tile != null) __texIndices.set(tile, 1.0);
        return tileId;
    }

    /** Set an explicit RGBA multiply color for this tile. */
    public function setTileColor(tile:Tile, r:Float, g:Float, b:Float, a:Float):Void {
        __tileColors.set(tile, [r, g, b, a]);
    }

    /** Remove per-tile color override (reverts to defaultColor). */
    public function clearTileColor(tile:Tile):Void {
        __tileColors.remove(tile);
    }

    override public function removeTile(tileId:Int):Bool {
        var tile = getTile(tileId);
        if (tile != null) {
            __texIndices.remove(tile);
            __clipRects.remove(tile);
            __tileColors.remove(tile);
            __tileTags.remove(tile);
            __removeRenderListEntry(tile, null);
        }
        return super.removeTile(tileId);
    }

    override public function removeTileInstance(tile:Tile):Bool {
        __texIndices.remove(tile);
        __clipRects.remove(tile);
        __tileColors.remove(tile);
        __tileTags.remove(tile);
        __removeRenderListEntry(tile, null);
        return super.removeTileInstance(tile);
    }

    private function __removeRenderListEntry(tile:Tile, hook:ImageHook):Void {
        var i = 0;
        while (i < __renderList.length) {
            var item = __renderList[i];
            if ((tile != null && item.isTile  && item.tile == tile) ||
                (hook != null && !item.isTile && item.hook == hook)) {
                __renderList.splice(i, 1);
                return;
            }
            i++;
        }
    }

    /** Called by Canvas.registerImageHook — appends to the render list. */
    public function addImageHook(hook:ImageHook):Void {
        __renderList.push({isTile: false, tile: null, hook: hook});
        if (pendingGroupTag > 0) __hookTags.set(hook, pendingGroupTag);
    }

    /** Called by Canvas.unregisterImageHook — removes from the render list. */
    public function removeImageHook(hook:ImageHook):Void {
        __hookTags.remove(hook);
        __removeRenderListEntry(null, hook);
    }

    /** Returns the ordered render list for Canvas.render() to walk. */
    public function getRenderList():Array<{isTile:Bool, tile:Tile, hook:ImageHook}> {
        return __renderList;
    }

    /**
     * Move all render list entries tagged with [tag] to the end, so the
     * owning window renders on top of all other controls.
     */
    public function raiseGroupToTop(tag:Int):Void {
        var toRaise:Array<{isTile:Bool, tile:Tile, hook:ImageHook}> = [];
        var i = 0;
        while (i < __renderList.length) {
            var item = __renderList[i];
            var itemTag = item.isTile ? __tileTags.get(item.tile) : __hookTags.get(item.hook);
            if (itemTag == tag) {
                toRaise.push(item);
                __renderList.splice(i, 1);
            } else i++;
        }
        for (item in toRaise) __renderList.push(item);
    }

    /** Build one tile into the vertex buffer — 10 floats per vertex (x,y,z,u,v,ti,r,g,b,a). */
    override public function buildTile(tile:Tile):Void {
        var region = atlasRegions.get(tile.regionId);
        if (region == null) {
            region = new AtlasRegion();
            region.u1 = -1.0; region.v1 = -1.0;
            region.u2 = -1.0; region.v2 = -1.0;
        }

        // V flip: uv1 = visual-bottom UV, uv2 = visual-top UV (y-down screen coords)
        var uv1 = region.v2;
        var uv2 = region.v1;

        var tx = tile.x + tile.offsetX;
        var ty = tile.y + tile.offsetY;
        var tw = tile.width;
        var th = tile.height;
        var hw = tw * 0.5;
        var hh = th * 0.5;
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

        // Per-vertex color: font tiles always white; graphic tiles use tile or default
        var col:Array<Float> = ti > 0.5 ? __WHITE : (__tileColors.get(tile) != null ? __tileColors.get(tile) : defaultColor);
        var cr = col[0]; var cg = col[1]; var cb = col[2]; var ca = col[3];

        // ── Clip rect handling ────────────────────────────────────────────────
        var clip = __clipRects.get(tile);
        if (clip != null) {
            // Tile world bounds (y-down screen coords; ty = visual top)
            var wx1 = tx;        var wy1 = ty;
            var wx2 = tx + tw;   var wy2 = ty + th;

            // Fully outside → emit nothing
            if (wx2 <= clip.x1 || wx1 >= clip.x2 || wy2 <= clip.y1 || wy1 >= clip.y2) return;

            // Partially inside + no rotation → clamp geometry and remap UVs
            if (tile.rotation == 0.0 && (wx1 < clip.x1 || wy1 < clip.y1 || wx2 > clip.x2 || wy2 > clip.y2)) {
                var clx1 = Math.max(wx1, clip.x1);
                var cly1 = Math.max(wy1, clip.y1);  // new visual top
                var clx2 = Math.min(wx2, clip.x2);
                var cly2 = Math.min(wy2, clip.y2);  // new visual bottom

                // Remap U proportionally along X
                var cu1 = region.u1 + (clx1 - wx1) / tw * (region.u2 - region.u1);
                var cu2 = region.u1 + (clx2 - wx1) / tw * (region.u2 - region.u1);

                // Remap V proportionally along Y (uv2 = visual-top, uv1 = visual-bottom)
                var cuv_top    = uv2 + (cly1 - wy1) / th * (uv1 - uv2);
                var cuv_bottom = uv2 + (cly2 - wy1) / th * (uv1 - uv2);

                // Emit clipped quad — same vertex order as normal path (high-y first)
                vertices.push(clx1); vertices.push(cly2); vertices.push(0.0); vertices.push(cu1); vertices.push(cuv_bottom); vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
                vertices.push(clx2); vertices.push(cly2); vertices.push(0.0); vertices.push(cu2); vertices.push(cuv_bottom); vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
                vertices.push(clx2); vertices.push(cly1); vertices.push(0.0); vertices.push(cu2); vertices.push(cuv_top);    vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
                vertices.push(clx1); vertices.push(cly1); vertices.push(0.0); vertices.push(cu1); vertices.push(cuv_top);    vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
                __verticesToRender += 4;
                __indicesToRender  += 6;
                return;
            }
            // Fully inside (or rotated partial) → fall through to normal path
        }

        // ── Normal (unclipped) path ────────────────────────────────────────────────
        // Top-left
        vertices.push(-hw * cosA - hh * sinA + cx); vertices.push(-hw * sinA + hh * cosA + cy); vertices.push(0.0); vertices.push(region.u1); vertices.push(uv1); vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
        // Top-right
        vertices.push( hw * cosA - hh * sinA + cx); vertices.push( hw * sinA + hh * cosA + cy); vertices.push(0.0); vertices.push(region.u2); vertices.push(uv1); vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
        // Bottom-right
        vertices.push( hw * cosA + hh * sinA + cx); vertices.push( hw * sinA - hh * cosA + cy); vertices.push(0.0); vertices.push(region.u2); vertices.push(uv2); vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);
        // Bottom-left
        vertices.push(-hw * cosA + hh * sinA + cx); vertices.push(-hw * sinA - hh * cosA + cy); vertices.push(0.0); vertices.push(region.u1); vertices.push(uv2); vertices.push(ti); vertices.push(cr); vertices.push(cg); vertices.push(cb); vertices.push(ca);

        __verticesToRender += 4;
        __indicesToRender  += 6;
    }

    /**
     * Override updateBuffers to use the 6-float orphan size and to call our
     * overridden buildTile instead of the base 5-float version.
     *
     * When Canvas drives segmented rendering it sets `segmentTiles` to the
     * subset of tiles for the current segment before calling
     * renderDisplayObject.  When null, the legacy full-batch path is used
     * (e.g. when there are no ImageViews in the control tree).
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!__active || textures[0] == null) return;

        if (segmentTiles != null) {
            for (tile in segmentTiles) {
                if (tile.visible) buildTile(tile);
            }
        } else {
            for (item in __renderList) {
                if (item.isTile && item.tile.visible) buildTile(item.tile);
            }
        }

        if (vertices.length > 0) {
            renderer.orphanAndUploadData(this, MAX_TILES_UI * 4 * 10 * 4);
        }

        needsBufferUpdate = false;
    }
}

// =============================================================================
// UIFontFace — private font proxy that submits glyph tiles into UIBatch with
// texIndex = 1.0. Implements IFontSource so Text can use it transparently.
//
// Multiple UIFontFace instances may share the same UIBatch (one per baked face).
// Character regions are registered once in the constructor using
// UIBatch.defineFontRegion() so UVs are computed relative to the font texture.
// =============================================================================

private class UIFontFace implements IFontSource {

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
// ClipRect — axis-aligned clip region in screen (y-down) coordinates.
// Stored as an object so all tiles sharing a handle automatically see
// updates when the owning ScrollableContainer moves.
// =============================================================================

private class ClipRect {
    public var x1:Float; public var y1:Float;
    public var x2:Float; public var y2:Float;
    public function new(x1:Float, y1:Float, x2:Float, y2:Float) {
        this.x1 = x1; this.y1 = y1; this.x2 = x2; this.y2 = y2;
    }
    public inline function set(x1:Float, y1:Float, x2:Float, y2:Float):Void {
        this.x1 = x1; this.y1 = y1; this.x2 = x2; this.y2 = y2;
    }
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
