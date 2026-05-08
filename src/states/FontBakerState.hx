package states;

import gui.Canvas;
import gui.ImageView;
import gui.Label;
import gui.TextField;
import gui.Toolstripmenu;
import gui.Window;
import loaders.FontLoader;
import Scancode;
import utils.BakedFontData;
import utils.FontBaker;
import utils.NativeDialog;

/**
 * FontBakerState - Tool state for baking TrueType fonts into bitmap atlases.
 *
 * Workflow:
 *   1. Enter the path to a TTF file in the Options window (left panel).
 *   2. Enter the desired font size in pixels.
 *   3. Click "Bake" to generate the bitmap atlas and preview it on screen.
 *   4. Click "Export" to write the JSON fontdata and TGA atlas to res/fonts/.
 *   5. Click "Back" (or press ESCAPE) to return to the menu.
 */
class FontBakerState extends State {

    // ── Layout constants ──────────────────────────────────────────────────────
    private static inline var TOOLSTRIP_H:Int    = 24;
    private static inline var OPTIONS_W:Int      = 220;
    private static inline var OPTIONS_MARGIN:Int = 4;
    private static inline var DEFAULT_FONT_SIZE:Int = 16;
    private static inline var ATLAS_SIZE:Int     = 512;

    // ── GUI ───────────────────────────────────────────────────────────────────
    private var _canvas:Canvas;

    private var _optionsWindow:Window;
    private var _pathField:TextField;
    private var _sizeField:TextField;

    private var _atlasView:ImageView;
    private var _statusLabel:Label;

    // ── State ─────────────────────────────────────────────────────────────────
    private var _bakedFont:Null<BakedFontData> = null;

    // ─────────────────────────────────────────────────────────────────────────

    public function new(app:App) {
        super("FontBaker", app);
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override public function init():Void {
        super.init();

        camera.ortho = true;

        var renderer = app.renderer;

        renderer.createProgramInfo("ui", null,
            app.resources.getText("shaders/ui.frag"));

        // Required by ImageView.
        renderer.createProgramInfo("textured",
            app.resources.getText("shaders/textured.vert"),
            app.resources.getText("shaders/textured.frag"));

        var spriteTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gui_debug.tga"));
        var fontTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gohu14.tga"));
        var fontData = FontLoader.load(
            app.resources.getText("fonts/gohu14.json"));

        var ws = app.window.size;
        _canvas = new Canvas(this, ws.x, ws.y);
        _canvas.initializeGraphics(renderer, spriteTexture, fontTexture, fontData);
        _canvas.setTint(0.588, 0.690, 0.518);
        _canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(_canvas);

        _buildUI();

        trace("FontBakerState: initialized");
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        if (app.input.keyboard.released(Scancode.ESCAPE)) {
            app.switchToStateByName("Menu");
        }
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (_canvas != null) _canvas.resize(width, height);
    }

    // ── UI construction ───────────────────────────────────────────────────────

    private function _buildUI():Void {
        var ws = app.window.size;

        // ── Menu bar ─────────────────────────────────────────────────────
        var menu = new Toolstripmenu();
        menu.addItem("File",   ["Open TTF", "Export", "Back"], _onFileMenu);
        menu.addItem("Bake",   ["Bake Font"],                  _onBakeMenu);
        _canvas.addControl(menu);

        // ── Options window (left panel) ───────────────────────────────────────
        var optH:Float = ws.y - TOOLSTRIP_H - OPTIONS_MARGIN * 2;
        _optionsWindow = new Window("Options", OPTIONS_W, optH,
            OPTIONS_MARGIN, TOOLSTRIP_H + OPTIONS_MARGIN);
        _canvas.addControl(_optionsWindow);

        // Controls inside the options window (coords are panel-relative).
        _optionsWindow.addControl(new Label("TTF Path:", 8, 8));
        _pathField = new TextField("", OPTIONS_W - 16, 8, 24);
        _optionsWindow.addControl(_pathField);

        _optionsWindow.addControl(new Label("Font Size (px):", 8, 52));
        _sizeField = new TextField("" + DEFAULT_FONT_SIZE, 60, 8, 68);
        _optionsWindow.addControl(_sizeField);

        // ── Main area ─────────────────────────────────────────────────────────
        var mainX:Float = OPTIONS_W + OPTIONS_MARGIN * 2;
        var mainY:Float = TOOLSTRIP_H + OPTIONS_MARGIN;
        var mainW:Float = ws.x - mainX - OPTIONS_MARGIN;
        var mainH:Float = ws.y - mainY - OPTIONS_MARGIN;

        _statusLabel = new Label("No font loaded.  Enter a TTF path and click Bake.", mainX, mainY + 4);
        _canvas.addControl(_statusLabel);

        var atlasY = mainY + 20;
        _atlasView = new ImageView(mainW, mainH - 20, mainX, atlasY);
        _canvas.addControl(_atlasView);
    }

    // ── Menu handlers ──────────────────────────────────────────────────────

    private function _onFileMenu(option:String):Void {
        switch (option) {
            case "Open TTF": _onOpen();
            case "Export":   _onExport();
            case "Back":     _onBack();
        }
    }

    private function _onBakeMenu(option:String):Void {
        _onBake();
    }

    private function _onOpen():Void {
        var path = NativeDialog.openFontFile();
        if (path == null) return; // user cancelled
        _pathField.text = path;
        _statusLabel.text = "Ready: " + path;
    }

    private function _onBake():Void {
        var path = StringTools.trim(_pathField.text);
        if (path.length == 0) {
            _statusLabel.text = "Enter a TTF path in the Options panel first.";
            return;
        }
        if (!sys.FileSystem.exists(path)) {
            _statusLabel.text = "File not found: " + path;
            return;
        }

        var sizeStr = StringTools.trim(_sizeField.text);
        var fontSize = Std.parseInt(sizeStr);
        if (fontSize == null || fontSize <= 0) fontSize = DEFAULT_FONT_SIZE;

        var fontBytes = sys.io.File.getBytes(path);

        // Derive a clean font name from the file name (no extension).
        var lastSlash = Std.int(Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\")));
        var baseName  = path.substring(lastSlash + 1);
        var dotPos    = baseName.lastIndexOf(".");
        var fontName  = dotPos > 0 ? baseName.substring(0, dotPos) : baseName;

        trace('FontBakerState: Baking "$fontName" at ${fontSize}px, atlas ${ATLAS_SIZE}x${ATLAS_SIZE}');

        _bakedFont = FontBaker.bakeFontFromBytes(fontBytes, fontName, fontSize,
            ATLAS_SIZE, ATLAS_SIZE);

        // Upload the RGBA atlas pixels into the ImageView.
        _atlasView.setPixels(_bakedFont.textureData.bytes, ATLAS_SIZE, ATLAS_SIZE, 4);

        _statusLabel.text = 'Baked: $fontName @ ${fontSize}px  (${ATLAS_SIZE}x${ATLAS_SIZE} atlas)';
    }

    private function _onExport():Void {
        if (_bakedFont == null) {
            _statusLabel.text = "Nothing to export — bake a font first.";
            return;
        }

        var outPath = "res/fonts/" + _bakedFont.fontName + "_" + _bakedFont.fontSize;
        _bakedFont.exportToFiles(outPath);
        _statusLabel.text = "Exported: " + outPath + ".json / .tga";
    }

    private function _onBack():Void {
        app.switchToStateByName("Menu");
    }
}
