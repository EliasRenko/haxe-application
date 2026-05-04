package gui;

import display.Text;
import gui.ControlEventType;
import gui.NineSlice;
import gui.TabPage;
import gui.ThreeSlice;

/**
 * TabControl - A tabbed container control.
 *
 * Usage:
 *   var tabs = new TabControl(200, 160, 10, 10);
 *   canvas.addControl(tabs);
 *
 *   var page1 = tabs.addTab("General");
 *   page1.addControl(new Label("Hello", 8, 8));
 *
 *   var page2 = tabs.addTab("Advanced");
 *   page2.addControl(new Checkbox(false, 8, 8));
 *
 * Only one tab page is visible at a time. Clicking a tab header
 * switches to that page and fires ON_TAB_INDEX_CHANGE.
 */
class TabControl extends Container<Control> {

    public static inline var TAB_HEIGHT:Int = 28;
    public static inline var TAB_WIDTH:Int  = 80;

    private var __nineSlice:NineSlice = new NineSlice();
    private var __tabs:Array<TabEntry> = [];
    private var __selectedIndex:Int = -1;

    public var selectedIndex(get, null):Int;

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = 'tabcontrol';
    }

    override function init():Void {
        // Background panel sits below the tab strip
        __nineSlice.iterate(function(tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });
        __initGraphics();
        __nineSlice.setWidth(__width);
        __nineSlice.setHeight(__height - TAB_HEIGHT);

        // Init all tab buttons and pages already queued via addTab()
        super.init();

        if (__tabs.length > 0 && __selectedIndex < 0) selectTab(0);
    }

    override function release():Void {
        __nineSlice.iterate(function(tile) ____canvas.tilemap.removeTileInstance(tile));
        super.release();
    }

    /**
     * Add a new tab. Returns the TabPage the caller can populate with controls.
     */
    public function addTab(title:String):TabPage {
        var index = __tabs.length;
        var btn  = new TabButton(title, TAB_WIDTH, index * TAB_WIDTH, 0);
        var page = new TabPage(__width, __height - TAB_HEIGHT, 0, TAB_HEIGHT);

        btn.addListener(function(c:Control, t:UInt) selectTab(index), LEFT_CLICK);

        __tabs.push({ button: btn, page: page });

        __addControl(btn);
        __addControl(page);

        // When added after init, hide non-first pages immediately
        if (____canvas != null) {
            if (index > 0) page.visible = false;
            else if (__selectedIndex < 0) selectTab(0);
        }

        return page;
    }

    public function selectTab(index:Int):Void {
        if (index < 0 || index >= __tabs.length) return;

        for (i in 0...__tabs.length) {
            __tabs[i].page.visible   = (i == index);
            __tabs[i].button.selected = (i == index);
        }

        __selectedIndex = index;
        dispatchEvent(this, ON_TAB_INDEX_CHANGE);
    }

    // -------------------------------------------------------------------------

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
        // Offset the panel background down by the tab strip height
        __nineSlice.setY(__y + ____offsetY + TAB_HEIGHT);
    }

    override function set_visible(value:Bool):Bool {
        __nineSlice.setVisible(value);
        return super.set_visible(value);
    }

    private function get_selectedIndex():Int {
        return __selectedIndex;
    }
}

// -----------------------------------------------------------------------------

private typedef TabEntry = { button:TabButton, page:TabPage };

/**
 * TabButton - Clickable tab header button.
 * Uses button_* tiles when inactive, strip_* tiles when active.
 */
private class TabButton extends Control {

    public static inline var DEFAULT_TILE_HEIGHT:Int = 28;

    public var selected(get, set):Bool;

    private var __threeSlice:ThreeSlice = new ThreeSlice();
    private var __bitmapText:Text;
    private var __title:String;
    private var __selected:Bool = false;

    public function new(title:String, width:Float, x:Float, y:Float) {
        super(x, y);
        __title   = title;
        __bitmapText = new Text(null, title, 0, 0);
        __width   = width;
        __height  = DEFAULT_TILE_HEIGHT;
        __type    = 'tabbutton';
    }

    override function init():Void {
        __threeSlice.iterate(function(tile) {
            tile.visible = visible;
            ____canvas.tilemap.addTileInstance(tile);
        });
        __threeSlice.setWidth(__width);
        __initGraphics();

        __bitmapText.font = ____canvas.font;
        __bitmapText.text = __title;

        super.init();
    }

    override function release():Void {
        __threeSlice.iterate(function(tile) ____canvas.tilemap.removeTileInstance(tile));
        __bitmapText.dispose();
        super.release();
    }

    private function __initGraphics():Void {
        if (__selected) {
            __threeSlice.get(0).regionId = ____canvas.sets.get('strip_1');
            __threeSlice.get(1).regionId = ____canvas.sets.get('strip_2');
            __threeSlice.get(2).regionId = ____canvas.sets.get('strip_3');
        } else {
            __threeSlice.get(0).regionId = ____canvas.sets.get('button_0');
            __threeSlice.get(1).regionId = ____canvas.sets.get('button_1');
            __threeSlice.get(2).regionId = ____canvas.sets.get('button_2');
        }
    }

    override function __setGraphicX():Void {
        __bitmapText.x = Math.round(__x + ____offsetX + (__width / 2) - (__bitmapText.width / 2));
        __threeSlice.setX(__x + ____offsetX);
    }

    override function __setGraphicY():Void {
        __bitmapText.y = __y + ____offsetY + 2;
        __threeSlice.setY(__y + ____offsetY);
    }

    override function set_visible(value:Bool):Bool {
        __threeSlice.setVisible(value);
        __bitmapText.visible = value;
        return super.set_visible(value);
    }

    private function get_selected():Bool {
        return __selected;
    }

    private function set_selected(value:Bool):Bool {
        __selected = value;
        if (__active) __initGraphics();
        return value;
    }
}
