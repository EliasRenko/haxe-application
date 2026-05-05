package gui;

import display.Text;
import display.Tile;
import gui.ControlEventType;
import gui.NineSlice;
import gui.ThreeSlice;

/**
 * Dropdown — A single-select dropdown control.
 *
 * Usage:
 *   var dd = new Dropdown(120, 10, 10);
 *   dd.addItem("Option A");
 *   dd.addItem("Option B");
 *   dd.addListener(onChanged, ON_ITEM_CLICK);
 *   canvas.addControl(dd);
 *
 *   trace(dd.selectedIndex);   // -1 until something is picked
 *   trace(dd.selectedValue);   // "" until something is picked
 *
 * Fires ON_ITEM_CLICK whenever the selection changes.
 *
 * The popup panel is created fresh on each open and added directly to the
 * Canvas overlay layer (tiles land at the end of the batch → always on top).
 * It also pushes itself to the Canvas focus stack so nothing behind it
 * receives input while it is open.
 */
class Dropdown extends Container<Control> {

    public static inline var ROW_HEIGHT:Int = 24;

    // ── Public API ───────────────────────────────────────────────────────────

    public var selectedIndex(get, null):Int;
    public var selectedValue(get, null):String;

    // ── Privates ─────────────────────────────────────────────────────────────

    private var __header:DropdownHeader;
    private var __popup:DropdownPopup = null;
    private var __items:Array<String> = [];
    private var __selectedIndex:Int = -1;
    private var __open:Bool = false;

    public function new(width:Float, x:Float, y:Float) {
        super(width, ROW_HEIGHT, x, y);
        __type = 'dropdown';
        __header = new DropdownHeader(width, 0, 0);
    }

    override function init():Void {
        __addControl(__header);
        __header.addListener(__onHeaderClick, LEFT_CLICK);
        super.init();
        // Re-apply any selection made before init (font was null then, tiles weren't built)
        if (__selectedIndex >= 0 && __selectedIndex < __items.length) {
            __header.__setText(__items[__selectedIndex]);
        }
    }

    // ── Public methods ───────────────────────────────────────────────────────

    public function addItem(label:String):Void {
        __items.push(label);
    }

    public function selectIndex(index:Int):Void {
        if (index < 0 || index >= __items.length) return;
        __selectedIndex = index;
        __header.__setText(__items[index]);
    }

    // ── Called by DropdownPopup when a row is selected ───────────────────────

    @:noCompletion
    public function __rowClicked(index:Int):Void {
        __selectedIndex = index;
        __header.__setText(__items[index]);
        __closePopup();
        dispatchEvent(this, ON_ITEM_CLICK);
    }

    // ── Internals ────────────────────────────────────────────────────────────

    private function __onHeaderClick(control:Control, type:UInt):Void {
        if (__open) {
            __closePopup();
        } else {
            __openPopup();
        }
    }

    private function __openPopup():Void {
        __open = true;
        var absX = __x + ____offsetX;
        var absY = __y + ____offsetY + ROW_HEIGHT;
        __popup = new DropdownPopup(__width, absX, absY, this);
        for (item in __items) __popup.__addRow(item);
        ____canvas.pushOverlay(__popup);
        ____canvas.pushFocus(__popup);
    }

    private function __closePopup():Void {
        __open = false;
        if (__popup != null) {
            ____canvas.popFocus(__popup);
            ____canvas.removeOverlay(__popup);
            __popup = null;
        }
    }

    // ── Getters ──────────────────────────────────────────────────────────────

    private function get_selectedIndex():Int  return __selectedIndex;
    private function get_selectedValue():String {
        return __selectedIndex >= 0 ? __items[__selectedIndex] : "";
    }
}

// =============================================================================
//  DropdownHeader — the always-visible button row
// =============================================================================

private class DropdownHeader extends Control {

    private static inline var ARROW_W:Int = 24;

    private var __threeSlice:ThreeSlice = new ThreeSlice();
    private var __bitmapText:Text;
    private var __arrow:Tile;

    public function new(width:Float, x:Float, y:Float) {
        super(x, y);
        __width  = width;
        __height = Dropdown.ROW_HEIGHT;
        __bitmapText = new Text(null, "", 0, 0);
        __arrow  = new Tile(null, 0);
        __type   = 'dropdown_header';
    }

    override function init():Void {
        __threeSlice.iterate(function(tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });
        __threeSlice.setWidth(__width);
        __initGraphics();

        __arrow.width  = ARROW_W;
        __arrow.height = Dropdown.ROW_HEIGHT;
        ____canvas.tilemap.addTileInstance(__arrow);
        __arrow.visible = visible;

        __bitmapText.font = ____canvas.font;

        super.init();
    }

    override function release():Void {
        __threeSlice.iterate(function(tile) ____canvas.tilemap.removeTileInstance(tile));
        ____canvas.tilemap.removeTileInstance(__arrow);
        __bitmapText.dispose();
        super.release();
    }

    public function __setText(value:String):Void {
        __bitmapText.text = value;
        __setGraphicX();
    }

    private function __initGraphics():Void {
        __threeSlice.get(0).regionId = ____canvas.sets.get('button_0');
        __threeSlice.get(1).regionId = ____canvas.sets.get('button_1');
        __threeSlice.get(2).regionId = ____canvas.sets.get('button_2');
        __arrow.regionId = ____canvas.sets.get('stamp_fold');
    }

    override function __setGraphicX():Void {
        __threeSlice.setX(__x + ____offsetX);
        __bitmapText.x = Math.round(__x + ____offsetX + 6);
        __arrow.x = __x + ____offsetX;
        __arrow.offsetX = __width - ARROW_W;
    }

    override function __setGraphicY():Void {
        __threeSlice.setY(__y + ____offsetY);
        __bitmapText.y = __y + ____offsetY + 2;
        __arrow.y = __y + ____offsetY;
    }

    override function set_visible(value:Bool):Bool {
        __threeSlice.setVisible(value);
        __arrow.visible = value;
        __bitmapText.visible = value;
        return super.set_visible(value);
    }

    override function set_width(value:Float):Float {
        __threeSlice.setWidth(value);
        return super.set_width(value);
    }
}

// =============================================================================
//  DropdownPopup — the panel that appears below the header
// =============================================================================

private class DropdownPopup extends Container<DropdownRow> {

    private var __nineSlice:NineSlice = new NineSlice();
    private var __dropdown:Dropdown;

    public function new(width:Float, x:Float, y:Float, dropdown:Dropdown) {
        super(width, 0, x, y);
        __dropdown = dropdown;
        __type = 'dropdown_popup';
    }

    override function init():Void {
        __nineSlice.iterate(function(tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });
        __initGraphics();
        __nineSlice.setWidth(__width);
        __nineSlice.setHeight(__height);
        super.init();
    }

    override function release():Void {
        __nineSlice.iterate(function(tile) ____canvas.tilemap.removeTileInstance(tile));
        super.release();
    }

    @:noCompletion
    public function __addRow(label:String):Void {
        var index = Lambda.count(__controls);
        var row = new DropdownRow(label, index, __width, 0, index * Dropdown.ROW_HEIGHT);
        var dd = __dropdown;
        row.addListener(function(c:Control, t:UInt) {
            dd.__rowClicked(cast(c, DropdownRow).__index);
        }, LEFT_CLICK);
        __addControl(row);

        __height = (index + 1) * Dropdown.ROW_HEIGHT;
        if (__active) __nineSlice.setHeight(__height);
    }

    private function __initGraphics():Void {
        __nineSlice.get(0).regionId = ____canvas.sets.get('panel_1');
        __nineSlice.get(1).regionId = ____canvas.sets.get('panel_2');
        __nineSlice.get(2).regionId = ____canvas.sets.get('panel_3');
        __nineSlice.get(3).regionId = ____canvas.sets.get('panel_4');
        __nineSlice.get(4).regionId = ____canvas.sets.get('panel_5');
        __nineSlice.get(5).regionId = ____canvas.sets.get('panel_6');
        __nineSlice.get(6).regionId = ____canvas.sets.get('panel_7');
        __nineSlice.get(7).regionId = ____canvas.sets.get('panel_8');
        __nineSlice.get(8).regionId = ____canvas.sets.get('panel_9');
    }

    override function __setGraphicX():Void {
        __nineSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {
        __nineSlice.setY(__y + ____offsetY);
    }

    override function set_visible(value:Bool):Bool {
        __nineSlice.setVisible(value);
        return super.set_visible(value);
    }

    override function set_height(value:Float):Float {
        __nineSlice.setHeight(value);
        return super.set_height(value);
    }
}

// =============================================================================
//  DropdownRow — one selectable row inside the popup
// =============================================================================

private class DropdownRow extends Control {

    @:noCompletion public var __index:Int;

    private var __graphic:Tile;
    private var __bitmapText:Text;

    public function new(label:String, index:Int, width:Float, x:Float, y:Float) {
        super(x, y);
        __index      = index;
        __width      = width;
        __height     = Dropdown.ROW_HEIGHT;
        __bitmapText = new Text(null, label, 0, 0);
        __graphic    = new Tile(null, 0);
        __type       = 'dropdown_row';
    }

    override function init():Void {
        __graphic.width  = __width;
        __graphic.height = __height;
        __graphic.regionId = ____canvas.sets.get('empty');
        __graphic.visible = false;
        ____canvas.tilemap.addTileInstance(__graphic);

        __bitmapText.font = ____canvas.font;
        __bitmapText.text = __bitmapText.text; // trigger tile build

        super.init();
    }

    override function release():Void {
        ____canvas.tilemap.removeTileInstance(__graphic);
        __bitmapText.dispose();
        super.release();
    }

    override function onMouseEnter():Void {
        __graphic.visible = true;
        super.onMouseEnter();
    }

    override function onMouseLeave():Void {
        __graphic.visible = false;
        super.onMouseLeave();
    }

    override function update():Void {
        if (____canvas.leftClick) {
            onMouseLeftClick();
        }
    }

    override function __setGraphicX():Void {
        __graphic.x   = __x + ____offsetX;
        __bitmapText.x = __x + ____offsetX + 6;
    }

    override function __setGraphicY():Void {
        __graphic.y   = __y + ____offsetY;
        __bitmapText.y = __y + ____offsetY + 2;
    }

    override function set_visible(value:Bool):Bool {
        if (!value) __graphic.visible = false; // hover tile always off when row is hidden
        __bitmapText.visible = value;
        return super.set_visible(value);
    }
}
