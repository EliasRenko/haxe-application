package gui;

import display.Text;
import display.Tile;
import gui.NineSlice;
import gui.Strip;
import gui.ControlEventType;

/**
 * Toolstripmenu — A Windows-style menu bar.
 *
 * Usage:
 *   var menu = new Toolstripmenu();
 *   menu.addItem("File", ["New", "Open", "Save"], function(opt) trace(opt));
 *   menu.addItem("Edit", ["Undo", "Redo"]);
 *   canvas.addControl(menu);
 *
 * Each top-level label opens a dropdown panel when clicked.
 * The panel auto-dismisses when the user clicks outside it.
 */
class Toolstripmenu extends Container<Control> {

    private var __strip:ToolstripBar;
    private var __labels:Array<ToolstripLabel> = [];

    public function new() {
        super(640, 24, 0, 0);
        __strip = new ToolstripBar();
        __type  = 'toolstrip';
    }

    override function init():Void {
        __addControl(__strip);
        super.init();
    }

    /**
     * Add a top-level menu item.
     * @param text     Label shown in the strip bar.
     * @param options  Dropdown option strings.
     * @param onSelect Called with the selected option text when the user picks one.
     */
    public function addItem(text:String, options:Array<String>, ?onSelect:String->Void):Void {
        var lbl = new ToolstripLabel(text, options, onSelect, this, 0, 0);
        __labels.push(lbl);
        __strip.addControl(lbl);
    }

    /** Close every open panel except [active]. Called by ToolstripLabel on open. */
    @:noCompletion
    public function __closeAllExcept(active:ToolstripLabel):Void {
        for (lbl in __labels) {
            if (lbl != active) lbl.__closePopup();
        }
    }

    override function update():Void {
        super.update();
    }
}

// =============================================================================
//  ToolstripLabel — top-row clickable label that opens a dropdown panel
// =============================================================================

private class ToolstripLabel extends Label {

    private static inline var ROW_HEIGHT:Int = 24;

    private var __options:Array<String>;
    private var __onSelect:Null<String->Void>;
    private var __menu:Toolstripmenu;
    private var __popup:Null<ToolstripPanel> = null;
    private var __open:Bool = false;

    public function new(text:String, options:Array<String>, onSelect:Null<String->Void>,
                        menu:Toolstripmenu, x:Float, y:Float) {
        __options  = options;
        __onSelect = onSelect;
        __menu     = menu;
        super(text, x, y);
    }

    override function init():Void {
        super.init();
        addListener(__onLabelClick, LEFT_CLICK);
    }

    override function release():Void {
        __closePopup();
        super.release();
    }

    private function __onLabelClick(control:Control, type:UInt):Void {
        if (__open) __closePopup() else __openPopup();
    }

    private function __openPopup():Void {
        __menu.__closeAllExcept(this);
        __open  = true;
        var absX = __x + ____offsetX;
        var absY = __y + ____offsetY + ROW_HEIGHT;
        __popup  = new ToolstripPanel(absX, absY, this);
        for (option in __options) __popup.__addRow(option);
        ____canvas.pushOverlay(__popup);
        ____canvas.pushFocus(__popup);
    }

    @:noCompletion
    public function __closePopup():Void {
        __open = false;
        if (__popup != null) {
            ____canvas.popFocus(__popup);
            ____canvas.removeOverlay(__popup);
            __popup = null;
        }
    }

    /** Called by ToolstripPanel when a row is selected. */
    @:noCompletion
    public function __rowClicked(option:String):Void {
        if (__onSelect != null) __onSelect(option);
        __closePopup();
    }
}

// =============================================================================
//  ToolstripBar — the horizontal strip holding the top-level labels
// =============================================================================

private class ToolstripBar extends Toolstrip {

    public function new() {
        super(640, 0, 0);
    }
}

// =============================================================================
//  ToolstripPanel — the dropdown popup panel (overlay, not in __container)
// =============================================================================

private class ToolstripPanel extends Container<ToolstripPanelRow> {

    private static inline var MIN_WIDTH:Float = 128;

    private var __nineSlice:NineSlice = new NineSlice();
    private var __label:ToolstripLabel;

    public function new(x:Float, y:Float, label:ToolstripLabel) {
        super(MIN_WIDTH, 0, x, y);
        __label = label;
        __type  = 'toolstrip_panel';
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
    public function __addRow(text:String):Void {
        var index = Lambda.count(__controls);
        var row   = new ToolstripPanelRow(text, MIN_WIDTH, 0,
                        index * ToolstripPanelRow.ROW_HEIGHT);
        var lbl   = __label;
        row.addListener(function(c:Control, t:UInt) {
            lbl.__rowClicked(cast(c, ToolstripPanelRow).__text);
        }, LEFT_CLICK);
        __addControl(row);

        __height = (index + 1) * ToolstripPanelRow.ROW_HEIGHT;
        if (__active) __nineSlice.setHeight(__height);
    }

    private function __initGraphics():Void {
        __nineSlice.get(0).regionId = ____canvas.sets.get('panel_0');
        __nineSlice.get(1).regionId = ____canvas.sets.get('panel_1');
        __nineSlice.get(2).regionId = ____canvas.sets.get('panel_2');
        __nineSlice.get(3).regionId = ____canvas.sets.get('panel_3');
        __nineSlice.get(4).regionId = ____canvas.sets.get('panel_4');
        __nineSlice.get(5).regionId = ____canvas.sets.get('panel_5');
        __nineSlice.get(6).regionId = ____canvas.sets.get('panel_6');
        __nineSlice.get(7).regionId = ____canvas.sets.get('panel_7');
        __nineSlice.get(8).regionId = ____canvas.sets.get('panel_8');
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
//  ToolstripPanelRow — one selectable row inside ToolstripPanel
// =============================================================================

private class ToolstripPanelRow extends Control {

    public static inline var ROW_HEIGHT:Int = 24;

    @:noCompletion public var __text:String;

    private var __graphic:Tile;
    private var __bitmapText:Text;

    public function new(text:String, width:Float, x:Float, y:Float) {
        super(x, y);
        __text       = text;
        __width      = width;
        __height     = ROW_HEIGHT;
        __bitmapText = new Text(null, text, 0, 0);
        __graphic    = new Tile(null, 0);
        __type       = 'toolstrip_row';
    }

    override function init():Void {
        __graphic.width    = __width;
        __graphic.height   = __height;
        __graphic.regionId = ____canvas.sets.get('empty');
        __graphic.visible  = false;
        ____canvas.tilemap.addTileInstance(__graphic);

        __bitmapText.font = ____canvas.font;
        __bitmapText.text = __bitmapText.text; // trigger glyph tile build

        super.init();
    }

    override function release():Void {
        ____canvas.tilemap.removeTileInstance(__graphic);
        __bitmapText.dispose();
        super.release();
    }

    override function __setGraphicX():Void {
        __graphic.x    = __x + ____offsetX;
        __bitmapText.x = Math.round(__x + ____offsetX + 6);
    }

    override function __setGraphicY():Void {
        __graphic.y    = __y + ____offsetY;
        __bitmapText.y = __y + ____offsetY + 4;
    }

    override function set_visible(value:Bool):Bool {
        __graphic.visible    = value && __hover;
        __bitmapText.visible = value;
        return super.set_visible(value);
    }

    override function onMouseEnter():Void {
        __graphic.visible = true;
        super.onMouseEnter();
    }

    override function onMouseLeave():Void {
        __graphic.visible = false;
        super.onMouseLeave();
    }
}