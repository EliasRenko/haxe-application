package states;

import display.BitmapFont;
import display.ManagedTileBatch;
import entity.DisplayEntity;
import gui.Canvas;
import gui.Control;
import gui.ControlEventType;
import gui.Label;
import gui.List as GUIList;
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

    private static final ITEMS:Array<String> = ["NEW GAME", "LOAD GAME", "GUI TEST", "QUIT"];

    private static inline var MARGIN_LEFT:Float   = 60.0;
    private static inline var MARGIN_BOTTOM:Float = 140.0;

    private var canvas:Canvas;
    private var menuList:GUIList<Label>;
    private var menuLabels:Array<Label> = [];
    private var selectedIndex:Int = 0;

    public function new(app:App) {
        super("Menu", app);
    }

    override public function init():Void {
        super.init();

        camera.ortho = true;

        var renderer = app.renderer;

        renderer.createProgramInfo("textured",
            app.resources.getText("shaders/textured.vert"),
            app.resources.getText("shaders/textured.frag"));

        renderer.createProgramInfo("text",
            app.resources.getText("shaders/mono.vert"),
            app.resources.getText("shaders/text.frag"));

        var guiTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gui_debug.tga"));

        var uiTileBatch = new ManagedTileBatch(
            renderer, renderer.getProgramInfo("textured"), guiTexture);

        var font = new BitmapFont(renderer,
            renderer.uploadTexture(app.resources.getTexture("textures/nokia.tga")),
            FontLoader.load(app.resources.getText("fonts/nokia.json")));

        addEntity(new DisplayEntity(uiTileBatch, "gui_tiles"));
        addEntity(new DisplayEntity(font, "menu_font"));

        var ws = app.window.size;
        canvas = new Canvas(this, ws.x, ws.y);
        canvas.initializeGraphics(uiTileBatch, font);
        canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(canvas);

        _buildMenu();

        trace("MenuState: initialized");
    }

    // -------------------------------------------------------------------------
    //  UI setup
    // -------------------------------------------------------------------------

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

        updateHighlight();
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

        if (selectedIndex != prevIndex) {
            updateHighlight();
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

    private function updateHighlight():Void {
        for (i in 0...menuLabels.length) {
            menuLabels[i].text = (i == selectedIndex ? "> " : "  ") + ITEMS[i];
        }
    }

    private function _onItemClick(control:Control, type:UInt):Void {
        var i = 0;
        for (listItem in menuList.controls) {
            if (listItem == control) {
                selectedIndex = i;
                updateHighlight();
                onSelect(i);
                return;
            }
            i++;
        }
    }

    private function onSelect(index:Int):Void {
        switch (index) {
            case 0:
                trace("MenuState: New Game");
            case 1:
                trace("MenuState: Load Game");
            case 2:
                app.switchToStateByName("GUITest");
            case 3:
                trace("MenuState: Quit");
                @:privateAccess app.__active = false;
        }
    }
}
