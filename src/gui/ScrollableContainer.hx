package gui;

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

    private var __scrollY:Float = 0;
    private var __contentHeight:Float = 0;
    private var __clipHandle:Int = -1;

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = "scrollable_container";
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override function init():Void {
        // Allocate a persistent clip rect for this container's viewport
        __clipHandle = ____canvas.createClipRect(
            __x + ____offsetX, __y + ____offsetY, __width, __height);
        super.init(); // initialises any pre-queued children
    }

    override function release():Void {
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
    }

    override private function __initControl(control:Control):Void {
        // Tag all tiles the control registers with this container's clip rect
        ____canvas.activateClipRect(__clipHandle);
        super.__initControl(control);
        ____canvas.deactivateClipRect();

        // Track content height (control positions are local, before scroll offset)
        var bottom = @:privateAccess (control.__y + control.__height);
        if (bottom > __contentHeight) __contentHeight = bottom;
    }

    // ── Update ────────────────────────────────────────────────────────────────

    override function update():Void {
        // Consume mouse-wheel scroll when the pointer is over this container
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

    private function __applyScroll(delta:Float):Void {
        var maxScroll = Math.max(0.0, __contentHeight - __height);
        var clamped   = Math.max(0.0, Math.min(__scrollY + delta, maxScroll));
        if (clamped == __scrollY) return;
        __scrollY = clamped;
        for (control in __controls) {
            @:privateAccess control.____setOffsetY(__y + ____offsetY - __scrollY);
        }
    }

    private function __syncClipRect():Void {
        if (__clipHandle >= 0) {
            ____canvas.updateClipRect(
                __clipHandle, __x + ____offsetX, __y + ____offsetY, __width, __height);
        }
    }

    // ── Getters and setters ───────────────────────────────────────────────────

    private function get_scrollY():Float return __scrollY;

    private function set_scrollY(v:Float):Float {
        __applyScroll(v - __scrollY);
        return __scrollY;
    }

    private function get_contentHeight():Float return __contentHeight;
}
