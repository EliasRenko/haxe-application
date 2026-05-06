package states;

import display.ManagedTileBatch;
import entity.DisplayEntity;
import gui.Button;
import gui.Canvas;
import gui.Checkbox;
import gui.Control;
import gui.ControlEventType;
import gui.Label;
import gui.Panel;
import gui.ScrollableContainer;
import gui.Stamp;
import gui.Strip;
import gui.Dropdown;
import gui.ProgressBar;
import gui.TabControl;
import gui.TabPage;
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
        "Label", "Button", "Checkbox", "Strip", "Panel", "Window", "Stamp", "ScrollableContainer", "TabControl", "Dropdown", "ProgressBar"
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

        renderer.createProgramInfo("ui", null,
            app.resources.getText("shaders/ui.frag"));

        var spriteTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gui_debug.tga"));

        var fontTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gohu14.tga"));
        var fontData = FontLoader.load(
            app.resources.getText("fonts/gohu14.json"));

        var ws = app.window.size;
        canvas = new Canvas(this, ws.x, ws.y);
        canvas.initializeGraphics(renderer, spriteTexture, fontTexture, fontData);
        canvas.setTint(0.588, 0.690, 0.518);  // HL1 olive-green tint
        addEntity(new DisplayEntity(canvas.tilemap, "gui_tiles"));
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
            case 7: _showScrollableContainer(cx, cy);
            case 8: _showTabControl(cx, cy);
            case 9:  _showDropdown(cx, cy);
            case 10: _showProgressBar(cx, cy);
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

    private function _showDropdown(cx:Int, cy:Int):Void {
        var dd = cast(_track(new Dropdown(160, cx - 80, cy - 12)), Dropdown);
        dd.addItem("Option A");
        dd.addItem("Option B");
        dd.addItem("Option C");
        dd.addItem("Option D");
        dd.addListener(function(c, _) trace("Dropdown selected: " + cast(c, Dropdown).selectedValue), ON_ITEM_CLICK);
    }

    private function _showTabControl(cx:Int, cy:Int):Void {
        var tabs = cast(_track(new TabControl(220, 140, cx - 110, cy - 70)), TabControl);

        var page1:TabPage = tabs.addTab("General");
        page1.addControl(new Label("General settings", 8, 8));
        var chk = new Checkbox(false, 8, 32);
        page1.addControl(chk);
        page1.addControl(new Label("Enable feature", 44, 36));

        var page2:TabPage = tabs.addTab("Audio");
        page2.addControl(new Label("Audio settings", 8, 8));
        var chkMute = new Checkbox(false, 8, 32);
        page2.addControl(chkMute);
        page2.addControl(new Label("Mute", 44, 36));

        var page3:TabPage = tabs.addTab("Video");
        page3.addControl(new Label("Video settings", 8, 8));
        var chkFs = new Checkbox(false, 8, 32);
        page3.addControl(chkFs);
        page3.addControl(new Label("Fullscreen", 44, 36));
    }

    private function _showProgressBar(cx:Int, cy:Int):Void {
        var pb = cast(_track(new ProgressBar(200, cx - 100, cy - 14)), ProgressBar);
        pb.value = 0.7;
        _track(new Label("70%", cx + 108, cy - 8));
    }

    private function _showScrollableContainer(cx:Int, cy:Int):Void {
        // A 160×140 viewport, centred, containing 12 label rows (total ~200px)
        var sc = cast(_track(new ScrollableContainer(160, 140, cx - 80, cy - 70)), ScrollableContainer);
        for (i in 0...12) {
            sc.addControl(new Label("Row " + (i + 1) + " — scroll me", 4, i * 18));
        }
    }

    // ── State overrides ───────────────────────────────────────────────────────

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        if (app.input.keyboard.released(Scancode.ESCAPE)) {
            app.switchToStateByName("Menu");
        }

        if (app.input.keyboard.released(Scancode.E)) {
            _index = (_index + 1) % NAMES.length;
            _showComponent(_index);
        }

        if (app.input.keyboard.released(Scancode.Q)) {
            _index = (_index - 1 + NAMES.length) % NAMES.length;
            _showComponent(_index);
        }
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (canvas != null) canvas.resize(width, height);
    }
}
