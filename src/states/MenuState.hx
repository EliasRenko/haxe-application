package states;

import display.BitmapFont;
import display.Text;
import entity.DisplayEntity;
import loaders.FontLoader;

/**
 * MenuState - Main menu screen
 *
 * Displays a bottom-left aligned menu inspired by classic FPS games.
 *
 * Controls:
 *   UP / DOWN  — navigate menu items
 *   ENTER      — confirm selection
 *   ESCAPE     — quit
 */
class MenuState extends State {

    private static final ITEMS:Array<String> = ["NEW GAME", "LOAD GAME", "GUI TEST", "QUIT"];

    // Layout
    private static inline var MARGIN_LEFT:Float   = 60.0;
    private static inline var MARGIN_BOTTOM:Float = 140.0;
    private static inline var ITEM_SPACING:Float  = 28.0;

    private var font:BitmapFont;
    private var menuTexts:Array<Text> = [];
    private var selectedIndex:Int = 0;

    public function new(app:App) {
        super("Menu", app);
    }

    override public function init():Void {
        super.init();

        var renderer = app.renderer;

        // Font setup — pre-register "mono" so BitmapFont's @:shader("mono") resolves it
        var fontData  = FontLoader.load(app.resources.getText("fonts/nokia.json"));
        var texData   = app.resources.getTexture("textures/nokia.tga");
        var texture   = renderer.uploadTexture(texData);

        var vert = app.resources.getText("shaders/mono.vert");
        var frag = app.resources.getText("shaders/text.frag");
        renderer.createProgramInfo("text", vert, frag);

        font = new BitmapFont(renderer, texture, fontData);

        // Position items bottom-left
        var baseY:Float = app.WINDOW_HEIGHT - MARGIN_BOTTOM - (ITEMS.length - 1) * ITEM_SPACING;

        for (i in 0...ITEMS.length) {
            var t = new Text(font, ITEMS[i], MARGIN_LEFT, baseY + i * ITEM_SPACING);
            menuTexts.push(t);
        }

        // Wrap the shared font batch in a DisplayEntity so State.render() picks it up
        addEntity(new DisplayEntity(font, "menu_font_batch"));

        updateHighlight();

        trace("MenuState: initialized");
    }

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
            onSelect(ITEMS.length - 1); // Quit
        }
    }

    override public function release():Void {
        for (t in menuTexts) {
            t.dispose();
        }
        menuTexts = [];
        super.release();
    }

    // -------------------------------------------------------------------------
    //  Helpers
    // -------------------------------------------------------------------------

    /** Prefix the selected item with "> " and others with "  " for visual feedback. */
    private function updateHighlight():Void {
        for (i in 0...menuTexts.length) {
            var prefix = (i == selectedIndex) ? "> " : "  ";
            menuTexts[i].setText(prefix + ITEMS[i]);
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
