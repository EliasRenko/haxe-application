package states;

import display.ManagedTileBatch;
import entity.DisplayEntity;
import gui.Button;
import gui.Canvas;
import gui.Checkbox;
import gui.Control;
import gui.ControlEventType;
import gui.Label;
import gui.List as GUIList;
import gui.Window;
import loaders.FontLoader;

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

    private static final ITEMS:Array<String> = ["New game", "Load game", "Options", "GUI Test", "Quit"];

    private static inline var MARGIN_LEFT:Float   = 60.0;
    private static inline var MARGIN_BOTTOM:Float = 140.0;

    private var canvas:Canvas;
    private var menuList:GUIList<Label>;
    private var menuLabels:Array<Label> = [];
    private var selectedIndex:Int = 0;
    private var optionsWindow:MenuOptionsWindow;

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
        addEntity(new DisplayEntity(canvas.tilemap, "gui_tiles"));
        canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(canvas);

        _buildMenu();

        trace("MenuState: initialized");
    }

    // -------------------------------------------------------------------------
    //  UI setup
    // -------------------------------------------------------------------------

    private function _initOptionsWindow():Void {
        var ws = app.window.size;
        var ox = Math.round((ws.x - MenuOptionsWindow.WIDTH)  / 2);
        var oy = Math.round((ws.y - MenuOptionsWindow.HEIGHT) / 2);
        optionsWindow = new MenuOptionsWindow(ox, oy);
        canvas.addControl(optionsWindow);

        // Graphics
        optionsWindow.addControl(new Label("Graphics", 8, 8));
        var cbFullscreen = new Checkbox(false, 8, 28);
        optionsWindow.addControl(cbFullscreen);
        optionsWindow.addControl(new Label("Fullscreen", 44, 36));
        var cbVsync = new Checkbox(false, 8, 56);
        optionsWindow.addControl(cbVsync);
        optionsWindow.addControl(new Label("VSync", 44, 64));

        // Audio
        optionsWindow.addControl(new Label("Audio", 8, 92));
        var cbMute = new Checkbox(false, 8, 112);
        optionsWindow.addControl(cbMute);
        optionsWindow.addControl(new Label("Mute audio", 44, 120));

        // Close button
        var btnClose = new Button("Close", 80, 70, 148);
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

        if (app.input.keyboard.released(Keycode.UP)) {
            selectedIndex = (selectedIndex - 1 + ITEMS.length) % ITEMS.length;
        }
        if (app.input.keyboard.released(Keycode.DOWN)) {
            selectedIndex = (selectedIndex + 1) % ITEMS.length;
        }

        if (app.input.keyboard.released(Keycode.RETURN)) {
            onSelect(selectedIndex);
        }
        if (app.input.keyboard.released(Keycode.ESCAPE)) {
            onSelect(ITEMS.length - 1);
        }
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (canvas != null) canvas.resize(width, height);
    }

    // -------------------------------------------------------------------------
    //  Helpers
    // -------------------------------------------------------------------------

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

    private function _onOptionsClose(control:Control, type:UInt):Void {
        if (optionsWindow != null) optionsWindow.visible = false;
    }

    private function onSelect(index:Int):Void {
        switch (index) {
            case 0:
                trace("MenuState: New Game");
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
                trace("MenuState: Quit");
                @:privateAccess app.__active = false;
        }
    }
}

private class MenuOptionsWindow extends Window {

    public static inline var WIDTH:Float  = 220.0;
    public static inline var HEIGHT:Float = 208.0;

    public function new(x:Float, y:Float) {
        super("Options", WIDTH, HEIGHT, x, y);
    }
}
