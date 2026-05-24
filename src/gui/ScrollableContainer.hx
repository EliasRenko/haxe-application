package gui;

import display.Tile;
import gui.NineSlice;

/**
 * ScrollableContainer — a fixed-viewport container that clips its children
 * to its bounds and scrolls them vertically via the mouse wheel.
 *
 * Clipping strategy (hybrid CPU):
 *   - Tiles fully outside the viewport rect emit zero vertices (free).
 *   - Tiles that straddle the edge are geometry+UV clipped in UIBatch.buildTile.
 *   - No GL scissor, no extra vertex data — single unified batch preserved.
 *
 * Usage:
 *   var sc = new ScrollableContainer(200, 150, 10, 10);
 *   canvas.addControl(sc);
 *   sc.addControl(new Label("item 1", 0, 0));
 *   sc.addControl(new Label("item 2", 0, 16));
 */
class ScrollableContainer extends Container<Control> {

    /** Pixels scrolled from the top. Read-write; clamped to [0, maxScroll]. */
    public var scrollY(get, set):Float;

    /** Total pixel height of all added children (grows as controls are added). */
    public var contentHeight(get, null):Float;

    /** Pixels scrolled per mouse-wheel tick. */
    public var mouseScrollSpeed:Float = 5.0;

    /** Width of the scroll handle strip on the right edge. */
    public static inline var HANDLE_W:Int = 8;

    private var __scrollY:Float = 0;
    private var __contentHeight:Float = 0;
    private var __clipHandle:Int = -1;

    private var __nineSlice:NineSlice = new NineSlice();
    private var __handleTile:Tile = new Tile(null);

    private var __handleDragging:Bool = false;
    private var __handleDragStartY:Float = 0;
    private var __handleDragStartScroll:Float = 0;

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = "scrollable_container";
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override function init():Void {
        // Background NineSlice — all 9 tiles share the same region
        var bgId = ____canvas.sets.get('panel_dark_0');
        __nineSlice.iterate(function(tile) {
            tile.regionId = bgId;
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });
        __nineSlice.setWidth(__width);
        __nineSlice.setHeight(__height);
        __nineSlice.setX(__x + ____offsetX);
        __nineSlice.setY(__y + ____offsetY);

        // Clip rect narrowed by HANDLE_W so children never overlap the handle
        __clipHandle = ____canvas.createClipRect(
            __x + ____offsetX, __y + ____offsetY, __width - HANDLE_W, __height);

        super.init(); // initialises any pre-queued children

        // Handle tile — added after clip setup so it is never clipped
        __handleTile.regionId = ____canvas.sets.get('handle_0');
        __handleTile.width = HANDLE_W;
        __handleTile.visible = false;
        ____canvas.tilemap.addTileInstance(__handleTile);

        __syncHandle();
    }

    override function release():Void {
        __nineSlice.iterate(function(tile) {
            ____canvas.tilemap.removeTileInstance(tile);
        });
        ____canvas.tilemap.removeTileInstance(__handleTile);

        if (__clipHandle >= 0) {
            ____canvas.destroyClipRect(__clipHandle);
            __clipHandle = -1;
        }
        super.release();
    }

    // ── Control management ───────────────────────────────────────────────────

    public function addControl(control:Control):Control {
        return __addControl(control);
    }

    public function removeControl(control:Control):Void {
        __removeControl(control);
        // Recalculate content height
        __contentHeight = 0;
        for (c in __controls) {
            var bottom = @:privateAccess (c.__y + c.__height);
            if (bottom > __contentHeight) __contentHeight = bottom;
        }
        __syncHandle();
    }

    override private function __initControl(control:Control):Void {
        // Tag all tiles the control registers with this container's clip rect
        ____canvas.activateClipRect(__clipHandle);
        super.__initControl(control);
        ____canvas.deactivateClipRect();

        // Track content height (control positions are local, before scroll offset)
        var bottom = @:privateAccess (control.__y + control.__height);
        if (bottom > __contentHeight) __contentHeight = bottom;
        __syncHandle();
    }

    // ── Update ────────────────────────────────────────────────────────────────

    override function hitTest():Bool {
        return __handleDragging || super.hitTest();
    }

    override function update():Void {
        var mouse = ____canvas.parentState.app.input.mouse;
        var mx    = ____canvas.mouseX;
        var my    = ____canvas.mouseY;

        // Handle drag: begin
        if (!__handleDragging && mouse.pressed(0) && __handleTile.visible) {
            var hx = __handleTile.x;
            var hy = __handleTile.y;
            if (mx >= hx && mx <= hx + HANDLE_W && my >= hy && my <= hy + __handleTile.height) {
                __handleDragging = true;
                __handleDragStartY      = my;
                __handleDragStartScroll = __scrollY;
            }
        }

        // Handle drag: continue / release
        if (__handleDragging) {
            if (mouse.check(0)) {
                var maxScroll  = Math.max(0.0, __contentHeight - __height);
                var handleH    = Math.max(HANDLE_W, __height * __height / __contentHeight);
                var trackRange = __height - handleH;
                if (trackRange > 0) {
                    var ratio = (my - __handleDragStartY) / trackRange;
                    scrollY = __handleDragStartScroll + ratio * maxScroll;
                }
            } else {
                __handleDragging = false;
            }
            return; // skip child updates while dragging handle
        }

        // Normal mouse-wheel scroll when pointer is over the container
        var delta = ____canvas.mouseScrollY;
        if (delta != 0) __applyScroll(delta * mouseScrollSpeed);

        for (control in __controls) {
            if (control.hitTest()) {
                control.update();
                return;
            }
        }
        super.update();
    }

    // ── Offset propagation (bakes scroll into child offsets) ─────────────────

    override function ____setOffsetX(value:Float):Void {
        ____offsetX = value;
        __setGraphicX();
        for (control in __controls) {
            @:privateAccess control.____setOffsetX(__x + ____offsetX);
        }
        __syncClipRect();
    }

    override function ____setOffsetY(value:Float):Void {
        ____offsetY = value;
        __setGraphicY();
        for (control in __controls) {
            @:privateAccess control.____setOffsetY(__y + ____offsetY - __scrollY);
        }
        __syncClipRect();
    }

    override function set_x(value:Float):Float {
        super.set_x(value);
        __syncClipRect();
        return value;
    }

    override function set_y(value:Float):Float {
        super.set_y(value);
        __syncClipRect();
        return value;
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    override function __setGraphicX():Void {
        __nineSlice.setX(__x + ____offsetX);
        __syncHandle();
    }

    override function __setGraphicY():Void {
        __nineSlice.setY(__y + ____offsetY);
        __syncHandle();
    }

    private function __applyScroll(delta:Float):Void {
        var maxScroll = Math.max(0.0, __contentHeight - __height);
        var clamped   = Math.max(0.0, Math.min(__scrollY + delta, maxScroll));
        if (clamped == __scrollY) return;
        __scrollY = clamped;
        for (control in __controls) {
            @:privateAccess control.____setOffsetY(__y + ____offsetY - __scrollY);
        }
        __syncHandle();
    }

    private function __syncClipRect():Void {
        if (__clipHandle >= 0) {
            ____canvas.updateClipRect(
                __clipHandle, __x + ____offsetX, __y + ____offsetY, __width - HANDLE_W, __height);
        }
    }

    private function __syncHandle():Void {
        var maxScroll = Math.max(0.0, __contentHeight - __height);
        var show = maxScroll > 0 && __visible;
        __handleTile.visible = show;
        if (!show) return;

        var handleH = Math.max(HANDLE_W, __height * __height / __contentHeight);
        var handleY = (__scrollY / maxScroll) * (__height - handleH);

        __handleTile.height = handleH;
        __handleTile.x     = __x + ____offsetX + __width - HANDLE_W;
        __handleTile.y     = __y + ____offsetY + handleY;
    }

    // ── Getters and setters ───────────────────────────────────────────────────

    override function set_visible(value:Bool):Bool {
        __nineSlice.setVisible(value);
        if (!value) __handleTile.visible = false;
        else __syncHandle();
        return super.set_visible(value);
    }

    private function get_scrollY():Float return __scrollY;

    private function set_scrollY(v:Float):Float {
        __applyScroll(v - __scrollY);
        return __scrollY;
    }

    private function get_contentHeight():Float return __contentHeight;
}
