package states;

import DebugConsole;
import gui.Button;
import gui.Canvas;
import gui.Checkbox;
import gui.Control;
import gui.ControlEventType;
import gui.Dropdown;
import gui.Label;
import gui.List as GUIList;
import gui.TabControl;
import gui.TabPage;
import gui.Window;
import loaders.FontLoader;
import math.Vec2;
import Scancode;

/**
 * MenuState - Main menu screen
 *
 * Displays a bottom-left aligned menu using the GUI List component.
 *
 * Controls:
 *   UP / DOWN  — navigate menu items
 *   ENTER      — confirm selection
 *   ESCAPE     — quit
 *   Mouse      — click any item to select it
 */
class MenuState extends State {

    private static final ITEMS:Array<String> = ["New game", "Load game", "Options", "GUI Test", "Font Baker", "Quit"];

    private static inline var MARGIN_LEFT:Float   = 60.0;
    private static inline var MARGIN_BOTTOM:Float = 140.0;

    private var canvas:Canvas;
    private var menuList:GUIList<Label>; 
    private var menuLabels:Array<Label> = [];
    private var selectedIndex:Int = 0;
    private var optionsWindow:MenuOptionsWindow;
    private var newGameWindow:MenuNewGameWindow;
    private var console:DebugConsole;

    public function new(app:App) {
        super("Menu", app);
    }

    override public function init():Void {
        super.init();

        camera.ortho = true;

        var renderer = app.renderer;

        renderer.createProgramInfo("ui", null,
            app.resources.getText("shaders/ui.frag"));

        var spriteTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gui_debug.tga"));

        var fontTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/nokia.tga"));
        var fontData = FontLoader.load(
            app.resources.getText("fonts/nokia.json"));

        var ws = app.window.size;
        canvas = new Canvas(this, ws.x, ws.y);
        canvas.initializeGraphics(renderer, spriteTexture, fontTexture, fontData);
        canvas.setTint(0.588, 0.690, 0.518);  // HL1 olive-green tint
        canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(canvas);

        _buildMenu();

        console = new DebugConsole(app, canvas);
        console.visible = false;

        trace("MenuState: initialized");
    }

    // -------------------------------------------------------------------------
    //  UI setup
    // -------------------------------------------------------------------------

    private function _initNewGameWindow():Void {
        var ws = app.window.size;
        var ox = Math.round((ws.x - MenuNewGameWindow.WIDTH)  / 2);
        var oy = Math.round((ws.y - MenuNewGameWindow.HEIGHT) / 2);
        newGameWindow = new MenuNewGameWindow(ox, oy);
        canvas.addControl(newGameWindow);

        // Panel height = HEIGHT - strip(28) = 192
        // Bottom buttons sit at panel-y = 192 - 28 - 8 = 156
        var btnY = MenuNewGameWindow.HEIGHT - 28 - 28 - 8;
        var btnX1 = Math.round((MenuNewGameWindow.WIDTH - 168) / 2); // (240-168)/2=36
        var btnX2 = btnX1 + 80 + 8;

        // Map selector
        newGameWindow.addControl(new Label("Map", 8, 8));
        var ddMap = new Dropdown(Math.round(MenuNewGameWindow.WIDTH - 16), 8, 26);
        ddMap.addItem("Map1");
        ddMap.addItem("Map2");
        ddMap.addItem("Map3");
        ddMap.selectIndex(0);
        newGameWindow.addControl(ddMap);

        // Cancel button
        var btnCancel = new Button("Cancel", 80, btnX1, btnY);
        btnCancel.addListener(_onNewGameClose, LEFT_CLICK);
        newGameWindow.addControl(btnCancel);

        // Start button
        var btnStart = new Button("Start", 80, btnX2, btnY);
        btnStart.addListener(_onNewGameStart, LEFT_CLICK);
        newGameWindow.addControl(btnStart);
    }

    private function _initOptionsWindow():Void {
        var ws = app.window.size;
        var margin:Int = 40;
        var w = ws.x - margin * 2;
        var h = ws.y - margin * 2;
        optionsWindow = new MenuOptionsWindow(w, h, margin, margin);
        canvas.addControl(optionsWindow);

        // Tab control fills the panel, leaving room for the Close button
        var tabW = w - 16;
        var tabH = h - 28 - 50; // 28 = window strip, 50 = close button area
        var tabs = new TabControl(tabW, tabH, 8, 8);
        optionsWindow.addControl(tabs);

        // ── Graphics tab ──────────────────────────────────────────────────
        var gfx:TabPage = tabs.addTab("Graphics");

        gfx.addControl(new Label("Display Mode", 8, 8));
        var ddDisplay = new Dropdown(160, 8, 26);
        ddDisplay.addItem("Windowed");
        ddDisplay.addItem("Fullscreen");
        ddDisplay.selectIndex(0);
        gfx.addControl(ddDisplay);

        gfx.addControl(new Label("Resolution", 8, 62));
        var ddRes = new Dropdown(160, 8, 80);
        ddRes.addItem("1920 x 1080");
        ddRes.addItem("1280 x 720");
        ddRes.addItem("1024 x 768");
        ddRes.addItem("800 x 600");
        ddRes.selectIndex(0);
        ddRes.addListener(function(c:Control, t:UInt) {
            var res = _resolutionFromLabel(ddRes.selectedValue);
            if (res != null) app.window.size = res;
        }, ON_ITEM_CLICK);
        gfx.addControl(ddRes);

        gfx.addControl(new Label("Aspect Ratio", 8, 116));
        var ddAspect = new Dropdown(160, 8, 134);
        ddAspect.addItem("16:9");
        ddAspect.addItem("16:10");
        ddAspect.addItem("4:3");
        ddAspect.addItem("21:9");
        ddAspect.selectIndex(0);
        gfx.addControl(ddAspect);

        var cbVsync = new Checkbox(false, 8, 170);
        gfx.addControl(cbVsync);
        gfx.addControl(new Label("VSync", 44, 174));

        // ── Audio tab ─────────────────────────────────────────────────────
        var audio:TabPage = tabs.addTab("Audio");

        var cbMute = new Checkbox(false, 8, 8);
        audio.addControl(cbMute);
        audio.addControl(new Label("Mute audio", 44, 12));

        // ── Close button ──────────────────────────────────────────────────
        var btnClose = new Button("Close", 80, Math.round((w - 80) / 2), h - 28 - 38);
        btnClose.addListener(_onOptionsClose, LEFT_CLICK);
        optionsWindow.addControl(btnClose);
    }

    private function _buildMenu():Void {
        menuLabels = [];
        selectedIndex = 0;

        var listY = app.WINDOW_HEIGHT - MARGIN_BOTTOM - (ITEMS.length - 1) * 28.0;

        menuList = new GUIList<Label>(200, MARGIN_LEFT, listY);
        menuList.addListener(_onItemClick, ON_ITEM_CLICK);

        for (item in ITEMS) {
            var label = new Label(item, 0, 0);
            menuLabels.push(label);
            menuList.addControl(label);
        }

        canvas.addControl(menuList);
    }

    // -------------------------------------------------------------------------
    //  Update
    // -------------------------------------------------------------------------

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        var prevIndex = selectedIndex;

        if (app.input.keyboard.released(Scancode.UP)) {
            selectedIndex = (selectedIndex - 1 + ITEMS.length) % ITEMS.length;
        }
        if (app.input.keyboard.released(Scancode.DOWN)) {
            selectedIndex = (selectedIndex + 1) % ITEMS.length;
        }

        if (app.input.keyboard.released(Scancode.RETURN)) {
            onSelect(selectedIndex);
        }
        if (app.input.keyboard.released(Scancode.ESCAPE)) {
            onSelect(ITEMS.length - 1);
        }
        if (app.input.keyboard.released(Scancode.GRAVE)) {
            console.visible = !console.visible;
        }
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (canvas != null) canvas.resize(width, height);
    }

    // -------------------------------------------------------------------------
    //  Helpers
    // -------------------------------------------------------------------------

    private function _resolutionFromLabel(label:String):Null<Vec2> {
        return switch (label) {
            case "1920 x 1080": new Vec2(1920, 1080);
            case "1280 x 720":  new Vec2(1280, 720);
            case "1024 x 768":  new Vec2(1024, 768);
            case "800 x 600":   new Vec2(800,  600);
            default: null;
        };
    }

    private function _onItemClick(control:Control, type:UInt):Void {
        var i = 0;
        for (listItem in menuList.controls) {
            if (listItem == control) {
                selectedIndex = i;
                onSelect(i);
                return;
            }
            i++;
        }
    }

    private function _onNewGameClose(control:Control, type:UInt):Void {
        if (newGameWindow != null) newGameWindow.visible = false;
    }

    private function _onNewGameStart(control:Control, type:UInt):Void {
        trace("MenuState: Start game");
    }

    private function _onOptionsClose(control:Control, type:UInt):Void {
        if (optionsWindow != null) optionsWindow.visible = false;
    }

    private function onSelect(index:Int):Void {
        switch (index) {
            case 0:
                if (newGameWindow == null) {
                    _initNewGameWindow();
                } else {
                    newGameWindow.visible = !newGameWindow.visible;
                }
            case 1:
                trace("MenuState: Load Game");
            case 2:
                if (optionsWindow == null) {
                    _initOptionsWindow();
                } else {
                    optionsWindow.visible = !optionsWindow.visible;
                }
            case 3:
                app.switchToStateByName("GUITest");
            case 4:
                app.switchToStateByName("FontBaker");
            case 5:
                trace("MenuState: Quit");
                @:privateAccess app.__active = false;
        }
    }
}

private class MenuNewGameWindow extends Window {

    public static inline var WIDTH:Float  = 240.0;
    public static inline var HEIGHT:Float = 220.0;

    public function new(x:Float, y:Float) {
        super("New Game", WIDTH, HEIGHT, x, y);
    }
}

private class MenuOptionsWindow extends Window {

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super("Options", width, height, x, y);
    }
}
