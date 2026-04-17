package states;

import display.BitmapFont;
import display.ManagedTileBatch;
import entity.DisplayEntity;
import gui.Button;
import gui.Canvas;
import gui.Checkbox;
import gui.Control;
import gui.ControlEventType;
import gui.Label;
import gui.Panel;
import gui.Stamp;
import gui.Strip;
import gui.Window;
import loaders.FontLoader;

/**
 * GUITestState - Cycle through each GUI component one at a time.
 *
 *   Q  →  previous component
 *   E  →  next component
 *   ESCAPE  →  back to MenuState
 *
 * The active component is centred on screen.
 * A label in the top-left shows the component name and index.
 */
class GUITestState extends State {

    private static final NAMES:Array<String> = [
        "Label", "Button", "Checkbox", "Strip", "Panel", "Window", "Stamp"
    ];

    private var canvas:Canvas;
    private var _index:Int = 0;
    private var _nameLabel:Label;
    private var _active:Array<Control> = [];

    public function new(app:App) {
        super("GUITest", app);
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
            renderer.uploadTexture(app.resources.getTexture("textures/gohu14.tga")),
            FontLoader.load(app.resources.getText("fonts/gohu14.json")));

        addEntity(new DisplayEntity(uiTileBatch, "gui_tiles"));
        addEntity(new DisplayEntity(font,        "gui_font"));

        var ws = app.window.size;
        canvas = new Canvas(this, ws.x, ws.y);
        canvas.initializeGraphics(uiTileBatch, font);
        canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(canvas);

        _buildUI();

        trace("GUITestState: initialized");
    }

    // ── Setup ─────────────────────────────────────────────────────────────────

    private function _buildUI():Void {
        _nameLabel = new Label("", 10, 10);
        canvas.addControl(_nameLabel);

        canvas.addControl(new Label("Q: prev   E: next", 10, 28));

        _showComponent(0);
    }

    // ── Component display ─────────────────────────────────────────────────────

    private function _clearActive():Void {
        for (c in _active) canvas.removeControl(c);
        _active = [];
    }

    private function _track(control:Control):Control {
        canvas.addControl(control);
        _active.push(control);
        return control;
    }

    private function _showComponent(index:Int):Void {
        _clearActive();

        _nameLabel.text = NAMES[index] + "  (" + (index + 1) + " / " + NAMES.length + ")";

        var cx = Math.round(canvas.width  / 2);
        var cy = Math.round(canvas.height / 2);

        switch (index) {
            case 0: _showLabel(cx, cy);
            case 1: _showButton(cx, cy);
            case 2: _showCheckbox(cx, cy);
            case 3: _showStrip(cx, cy);
            case 4: _showPanel(cx, cy);
            case 5: _showWindow(cx, cy);
            case 6: _showStamp(cx, cy);
        }
    }

    private function _showLabel(cx:Int, cy:Int):Void {
        _track(new Label("I am a Label control", cx - 60, cy));
    }

    private function _showButton(cx:Int, cy:Int):Void {
        var btn = new Button("Click Me", 120, cx - 60, cy - 14);
        btn.addListener(function(_, __) trace("Button clicked"), LEFT_CLICK);
        _track(btn);
    }

    private function _showCheckbox(cx:Int, cy:Int):Void {
        var chk = new Checkbox(false, cx - 50, cy - 14);
        chk.addListener(function(c, _) trace("Checkbox: " + cast(c, Checkbox).value), LEFT_CLICK);
        _track(chk);
        _track(new Label("Toggle me", cx - 14, cy - 8));
    }

    private function _showStrip(cx:Int, cy:Int):Void {
        var strip = cast(_track(new Strip(300, cx - 150, cy - 12)), Strip);
        strip.addControl(new Label("Strip toolbar", 10, 4));
        strip.addControl(new Stamp(canvas.getSet("stamp_close"), 268, 0));
    }

    private function _showPanel(cx:Int, cy:Int):Void {
        var panel = cast(_track(new Panel(180, 110, cx - 90, cy - 55)), Panel);
        panel.addControl(new Label("Panel Content", 8, 8));
        var btn = new Button("OK", 80, 8, 36);
        btn.addListener(function(_, __) trace("Panel OK clicked"), LEFT_CLICK);
        panel.addControl(btn);
        var chk = new Checkbox(false, 8, 72);
        panel.addControl(chk);
        panel.addControl(new Label("Inner option", 42, 76));
    }

    private function _showWindow(cx:Int, cy:Int):Void {
        var win = cast(_track(new Window("Test Window", 210, 140, cx - 105, cy - 70)), Window);
        win.addControl(new Label("Hello from Window", 8, 8));
        var btn = new Button("Press", 80, 8, 36);
        btn.addListener(function(_, __) trace("Window Press clicked"), LEFT_CLICK);
        win.addControl(btn);
    }

    private function _showStamp(cx:Int, cy:Int):Void {
        _track(new Stamp(canvas.getSet("stamp_close"), cx - 14, cy - 14));
    }

    // ── State overrides ───────────────────────────────────────────────────────

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        if (app.input.keyboard.released(Keycode.ESCAPE)) {
            app.switchToStateByName("Menu");
        }

        if (app.input.keyboard.released(Keycode.E)) {
            _index = (_index + 1) % NAMES.length;
            _showComponent(_index);
        }

        if (app.input.keyboard.released(Keycode.Q)) {
            _index = (_index - 1 + NAMES.length) % NAMES.length;
            _showComponent(_index);
        }
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (canvas != null) canvas.resize(width, height);
    }
}
