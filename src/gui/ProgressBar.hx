package gui;

import gui.Control;
import gui.ThreeSlice;

/**
 * ProgressBar — horizontal fill indicator.
 *
 * The track is rendered with `strip_1/2/3` tiles (same as Strip).
 * The fill is rendered on top with `button_0/1/2` tiles so it is
 * visually distinct via the existing atlas tint.
 *
 * Usage:
 *   var pb = new ProgressBar(200, x, y);
 *   canvas.addControl(pb);
 *   pb.value = 0.75;   // 75 %
 */
class ProgressBar extends Control {

    // ** Constants.
    public static inline var DEFAULT_TILE_HEIGHT:Int = 28;

    // ** Publics.
    /** Normalised fill level in the range [0, 1]. Clamped on set. */
    public var value(get, set):Float;

    // ** Privates.
    private var __bgSlice:ThreeSlice   = new ThreeSlice();
    private var __fillSlice:ThreeSlice = new ThreeSlice();
    private var __value:Float = 0.0;

    public function new(width:Float, x:Float, y:Float) {
        super(x, y);

        // Enforce minimum width so the ThreeSlice caps never overlap.
        __width  = Math.max(ThreeSlice.DEFAULT_TILE_WIDTH * 2, width);
        __height = DEFAULT_TILE_HEIGHT;
        __type   = 'progressbar';
    }

    override function init():Void {
        // Background track — added first so it renders below the fill.
        __bgSlice.iterate(function(tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });

        // Fill — added after so it renders on top of the track.
        __fillSlice.iterate(function(tile) {
            tile.visible = false;
            ____canvas.tilemap.addTileInstance(tile);
        });

        __initGraphics();
        __bgSlice.setWidth(__width);
        __updateFill();

        super.init();
    }

    override function release():Void {
        __bgSlice.iterate(function(tile)   ____canvas.tilemap.removeTileInstance(tile));
        __fillSlice.iterate(function(tile) ____canvas.tilemap.removeTileInstance(tile));

        super.release();
    }

    override function update():Void {
        // ProgressBar is non-interactive; no input handling needed.
    }

    // ── Graphics helpers ──────────────────────────────────────────────────────

    private function __initGraphics():Void {
        __bgSlice.get(0).regionId   = ____canvas.sets.get('strip_0');
        __bgSlice.get(1).regionId   = ____canvas.sets.get('strip_1');
        __bgSlice.get(2).regionId   = ____canvas.sets.get('strip_2');

        __fillSlice.get(0).regionId = ____canvas.sets.get('button_0');
        __fillSlice.get(1).regionId = ____canvas.sets.get('button_1');
        __fillSlice.get(2).regionId = ____canvas.sets.get('button_2');
    }

    /**
     * Resize and show/hide the fill ThreeSlice based on the current value.
     * Must only be called after `init()`.
     */
    private function __updateFill():Void {
        if (__value <= 0) {
            __fillSlice.setVisible(false);
            return;
        }

        var maxW  = __width - ThreeSlice.DEFAULT_TILE_WIDTH * 2;
        var fillW = maxW * __value;

        // setWidth expects the total ThreeSlice width (caps + middle).
        __fillSlice.setWidth(fillW + ThreeSlice.DEFAULT_TILE_WIDTH * 2);
        __fillSlice.setVisible(visible);
    }

    override function __setGraphicX():Void {
        __bgSlice.setX(__x + ____offsetX);
        __fillSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {
        __bgSlice.setY(__y + ____offsetY);
        __fillSlice.setY(__y + ____offsetY);
    }

    // ── Getters and setters ───────────────────────────────────────────────────

    override function set_visible(value:Bool):Bool {
        __bgSlice.setVisible(value);
        if (!value) {
            __fillSlice.setVisible(false);
        } else if (__value > 0) {
            __fillSlice.setVisible(true);
        }
        return super.set_visible(value);
    }

    override function set_width(value:Float):Float {
        var w = Math.max(ThreeSlice.DEFAULT_TILE_WIDTH * 2, value);
        __bgSlice.setWidth(w);
        var result = super.set_width(w);
        __updateFill();
        return result;
    }

    private function get_value():Float {
        return __value;
    }

    private function set_value(v:Float):Float {
        __value = Math.max(0.0, Math.min(1.0, v));
        __updateFill();
        return __value;
    }
}
