package gui;

import display.Tile;
import haxe.ds.Vector;

/**
 * Table — a scrollable data grid with a fixed column header row.
 *
 * Usage:
 *   var t = new Table(300, 160, x, y);
 *   canvas.addControl(t);
 *   t.addColumn("Name",  120);
 *   t.addColumn("Value",  80);
 *   t.addColumn("Status", 80);
 *   t.addRow(["Player",  "100",  "Alive"]);
 *   t.addRow(["Enemy",   "55",   "Dead"]);
 *   t.clearRows();   // wipe data without touching columns
 *
 * Layout:
 *   • A Strip header spanning the full width, with one Label per column.
 *   • A ScrollableContainer body immediately below the header.
 *   • Each row is a flat container: alternating panel / plain background,
 *     with one Label per cell, clipped to the scroll viewport.
 */
class Table extends Container<Control> {

    public static inline var ROW_HEIGHT:Int     = 18;
    public static inline var HEADER_HEIGHT:Int  = 28;   // Strip height
    public static inline var CELL_PADDING_X:Int = 4;
    public static inline var CELL_PADDING_Y:Int = 3;

    // ── Public API ─────────────────────────────────────────────────────────────

    /** Number of data rows currently in the table. */
    public var rowCount(get, null):Int;

    // ── Privates ───────────────────────────────────────────────────────────────

    private var __header:TableHeader;
    private var __body:ScrollableContainer;
    private var __columns:Array<{name:String, width:Float}> = [];
    private var __rowCount:Int = 0;

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = 'table';
    }

    override function init():Void {
        var bodyHeight = __height - HEADER_HEIGHT;

        __header = new TableHeader(__width);
        __addControl(__header);

        __body = new ScrollableContainer(__width, bodyHeight, 0, HEADER_HEIGHT);
        __addControl(__body);

        // Re-add any columns/rows queued before the canvas was available.
        // (Typically addColumn / addRow are called after canvas.addControl(table),
        //  so __controls is empty here.  This guard is future-proof.)
        super.init();
    }

    override function release():Void {
        super.release();
    }

    /**
     * Append a column.  Must be called before addRow so column widths are known.
     * @param name  Header label text
     * @param width Column width in pixels (excluding padding)
     */
    public function addColumn(name:String, width:Float):Void {
        __columns.push({name: name, width: width});
        if (__header != null && __header.active) {
            __header.addColumnLabel(name, width, __columns.length - 1);
        }
    }

    /**
     * Append a data row.
     * @param values  Array of cell strings; extra values are ignored,
     *                missing values become empty strings.
     */
    public function addRow(values:Array<String>):Void {
        if (__body == null) return;
        var y = __rowCount * ROW_HEIGHT;
        var row = new TableRow(values, __columns, __rowCount, __width, y);
        __body.addControl(row);
        __rowCount++;
    }

    /** Remove all data rows from the table body. */
    public function clearRows():Void {
        if (__body == null) return;
        // Collect first, then remove (avoids mutating during iteration).
        var toRemove:Array<Control> = [];
        for (c in @:privateAccess __body.__controls) toRemove.push(c);
        for (c in toRemove) __body.removeControl(c);
        __rowCount = 0;
    }

    override function update():Void {
        // Delegate entirely to children; Table itself is not interactive.
        for (control in @:privateAccess __controls) {
            if (control.hitTest()) {
                control.update();
                return;
            }
        }
    }

    private function get_rowCount():Int { return __rowCount; }
}

// ─────────────────────────────────────────────────────────────────────────────
// TableHeader — a Strip that holds one Label per column.
// ─────────────────────────────────────────────────────────────────────────────

private class TableHeader extends Strip {

    private var __cursorX:Float = 0;

    public function new(width:Float) {
        super(width, 0, 0);
    }

    public function addColumnLabel(name:String, colWidth:Float, index:Int):Void {
        var lbl = new Label(name, __cursorX + Table.CELL_PADDING_X, Table.CELL_PADDING_Y);
        addControl(lbl);
        __cursorX += colWidth;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TableRow — a single data row with alternating background tint.
// ─────────────────────────────────────────────────────────────────────────────

private class TableRow extends Container<Control> {

    // A single stretched tile for even-row backgrounds.
    // NineSlice is intentionally avoided: NineSlice.setHeight() breaks for
    // heights smaller than 2 × DEFAULT_TILE_HEIGHT (28px), producing negative
    // middle-section heights and negative bottom-row offsets that render the
    // bottom tiles upward over the next row, hiding its text.
    private var __bgTile:Tile = null;
    private var __even:Bool;

    public function new(values:Array<String>,
                        columns:Array<{name:String, width:Float}>,
                        rowIndex:Int, totalWidth:Float, y:Float) {
        super(totalWidth, Table.ROW_HEIGHT, 0, y);
        __type = 'tablerow';
        __even = (rowIndex % 2 == 0);

        // Build cells
        var cursorX:Float = 0;
        for (i in 0...columns.length) {
            var col = columns[i];
            var text = i < values.length ? values[i] : "";
            __addPreInitControl(new Label(text, cursorX + Table.CELL_PADDING_X, Table.CELL_PADDING_Y));
            cursorX += col.width;
        }
    }

    // Queue a child before init (no canvas yet).
    private function __addPreInitControl(control:Control):Void {
        @:privateAccess __controls.add(cast control);
    }

    override function init():Void {
        if (__even) {
            __bgTile = new Tile(null);
            __bgTile.width    = __width;
            __bgTile.height   = Table.ROW_HEIGHT;
            __bgTile.x        = __x + ____offsetX;
            __bgTile.y        = __y + ____offsetY;
            __bgTile.regionId = ____canvas.sets.get('panel_4');
            ____canvas.tilemap.addTileInstance(__bgTile);
        }
        super.init();
    }

    override function release():Void {
        if (__bgTile != null) {
            ____canvas.tilemap.removeTileInstance(__bgTile);
            __bgTile = null;
        }
        super.release();
    }

    override function update():Void {
        for (control in @:privateAccess __controls) {
            if (control.hitTest()) {
                control.update();
                return;
            }
        }
    }

    override function __setGraphicX():Void {
        if (__bgTile != null) __bgTile.x = __x + ____offsetX;
    }

    override function __setGraphicY():Void {
        if (__bgTile != null) __bgTile.y = __y + ____offsetY;
    }

    override function set_visible(value:Bool):Bool {
        if (__bgTile != null) __bgTile.visible = value;
        return super.set_visible(value);
    }
}
