package states;

import display.BitmapFont;
import display.ManagedTileBatch;
import entity.DisplayEntity;
import gui.Button;
import gui.Canvas;
import gui.Checkbox;
import gui.ControlEventType;
import gui.Label;
import gui.Panel;
import gui.Stamp;
import gui.Strip;
import gui.Window;
import loaders.FontLoader;

/**
 * GUITestState - Interactive showcase of all Canvas GUI components.
 *
 * Layout (canvas-space, origin top-left):
 *   y= 10  Label header
 *   y= 40  Two buttons
 *   y= 80  Two checkboxes with labels
 *   y=120  Strip toolbar (3-slice) with a label and a stamp icon
 *   y=160  Panel (9-slice, w=180) with nested label / button / checkbox
 *   y=160  Window (w=210, x=200) with nested label and button
 *
 * ESCAPE → switch back to MenuState
 */
class GUITestState extends State {

    private var canvas:Canvas;

    public function new(app:App) {
        super("GUITest", app);
    }

    override public function init():Void {
        super.init();

        camera.ortho = true;

        var renderer = app.renderer;

        // ── Shaders ──────────────────────────────────────────────────────────
        renderer.createProgramInfo("textured",
            app.resources.getText("shaders/textured.vert"),
            app.resources.getText("shaders/textured.frag"));

        renderer.createProgramInfo("text",
            app.resources.getText("shaders/mono.vert"),
            app.resources.getText("shaders/text.frag"));

        // ── GUI sprite-sheet ──────────────────────────────────────────────────
        var guiTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gui_debug.tga"));

        var uiTileBatch = new ManagedTileBatch(
            renderer, renderer.getProgramInfo("textured"), guiTexture);

        // ── Bitmap font ───────────────────────────────────────────────────────
        var font = new BitmapFont(renderer,
            renderer.uploadTexture(app.resources.getTexture("textures/gohu14.tga")),
            FontLoader.load(app.resources.getText("fonts/gohu14.json")));

        // ── Register display objects for automatic rendering ──────────────────
        addEntity(new DisplayEntity(uiTileBatch, "gui_tiles"));
        addEntity(new DisplayEntity(font,        "gui_font"));

        // ── Canvas ────────────────────────────────────────────────────────────
        var ws = app.window.size;
        canvas = new Canvas(this, ws.x, ws.y);
        canvas.initializeGraphics(uiTileBatch, font);
        canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(canvas);

        // ── Build UI ──────────────────────────────────────────────────────────
        _buildUI();

        trace("GUITestState: initialized");
    }

    // ── UI layout ─────────────────────────────────────────────────────────────

    private function _buildUI():Void {

        // ── Header ────────────────────────────────────────────────────────────
        canvas.addControl(new Label("GUI Component Test", 10, 10));

        // ── Buttons ───────────────────────────────────────────────────────────
        var btnClick = new Button("Click Me", 120, 10, 40);
        btnClick.addListener(function(_, __) trace("Click Me pressed"), LEFT_CLICK);
        canvas.addControl(btnClick);

        var btnHover = new Button("Hover Me", 100, 140, 40);
        canvas.addControl(btnHover);

        // ── Checkboxes ────────────────────────────────────────────────────────
        var chkA = new Checkbox(false, 10, 80);
        chkA.addListener(function(c, _) trace("Checkbox A: " + cast(c, Checkbox).value), LEFT_CLICK);
        canvas.addControl(chkA);
        canvas.addControl(new Label("Option A", 44, 84));

        var chkB = new Checkbox(true, 160, 80);
        canvas.addControl(chkB);
        canvas.addControl(new Label("Option B", 194, 84));

        // ── Strip toolbar ─────────────────────────────────────────────────────
        var strip = new Strip(300, 10, 120);
        canvas.addControl(strip);
        strip.addControl(new Label("Toolbar", 10, 4));

        // Stamp uses the runtime region-id resolved from the atlas
        var closeStamp = new Stamp(canvas.getSet("stamp_close"), 268, 0);
        strip.addControl(closeStamp);

        // ── Panel with nested controls ─────────────────────────────────────────
        var panel = new Panel(180, 110, 10, 160);
        canvas.addControl(panel);
        panel.addControl(new Label("Panel Content", 8, 8));

        var pBtn = new Button("OK", 80, 8, 36);
        pBtn.addListener(function(_, __) trace("Panel OK clicked"), LEFT_CLICK);
        panel.addControl(pBtn);

        var pChk = new Checkbox(false, 8, 72);
        panel.addControl(pChk);
        panel.addControl(new Label("Inner option", 42, 76));

        // ── Window ────────────────────────────────────────────────────────────
        var win = new Window("Test Window", 210, 140, 202, 160);
        canvas.addControl(win);
        win.addControl(new Label("Hello from Window", 8, 8));

        var wBtn = new Button("Press", 80, 8, 36);
        wBtn.addListener(function(_, __) trace("Window Press clicked"), LEFT_CLICK);
        win.addControl(wBtn);
    }

    // ── State overrides ───────────────────────────────────────────────────────

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        if (app.input.keyboard.released(Keycode.ESCAPE)) {
            app.switchToStateByName("Menu");
        }
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (canvas != null) canvas.resize(width, height);
    }
}
