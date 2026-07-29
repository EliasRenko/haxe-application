package states;

import gui.Button;
import gui.Canvas;
import gui.Control;
import gui.ControlEventType;
import gui.Dropdown;
import gui.ImageView;
import gui.Label;
import gui.ScrollableContainer;
import gui.TextField;
import gui.Toolstripmenu;
import gui.Window;
import loaders.FontLoader;
import ScanCode;
import utils.BakedFontData;
import utils.FontBaker;
import utils.NativeDialog;

/**
 * FontBakerState - Tool for baking one or more TTF fonts into a shared atlas.
 *
 * Workflow:
 *   1. Add one or more font entries with "Add Font" (or File → Open TTF).
 *   2. Select an entry in the list to edit its path / size / name.
 *   3. Choose an atlas size from the dropdown.
 *   4. Click Bake → "Bake All" to pack all entries into a single atlas and
 *      preview it.
 *   5. File → Export to write one TGA + one JSON per face to res/fonts/.
 *   6. File → Back (or ESCAPE) to return to the menu.
 */
class FontBakerState extends State {

    // ── Layout ────────────────────────────────────────────────────────────────
    private static inline var MENU_H:Int         = 24;
    private static inline var OPTIONS_W:Int      = 240;
    private static inline var MARGIN:Int         = 4;
    private static inline var DEFAULT_SIZE:Int   = 16;
    private static inline var LIST_ITEM_H:Int    = 20;

    // ── GUI ───────────────────────────────────────────────────────────────────
    private var _canvas:Canvas;
    private var _listContainer:ScrollableContainer;
    private var _pathField:TextField;
    private var _sizeField:TextField;
    private var _nameField:TextField;
    private var _atlasDropdown:Dropdown;
    private var _atlasView:ImageView;
    private var _statusLabel:Label;

    // ── Font entries ──────────────────────────────────────────────────────────
    /** Each entry: { path, size, name } */
    private var _entries:Array<{ path:String, size:Int, name:String }> = [];
    private var _selectedIdx:Int = -1;

    // ── Last bake result ──────────────────────────────────────────────────────
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
        renderer.createProgramInfo("textured",
            app.resources.getText("shaders/textured.vert"),
            app.resources.getText("shaders/textured.frag"));

        var spriteTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/gui.tga"));

        // Shared font atlas — all 3 faces live in this one texture
        var fontTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/font_atlas.tga"));
        var fontData = FontLoader.load(
            app.resources.getText("fonts/gohu14.json"));

        var ws = app.window.size;
        _canvas = new Canvas(this, ws.x, ws.y);
        _canvas.initializeGraphics(renderer, spriteTexture, fontTexture, fontData);
        // Register the other two faces — they share the same fontTexture atlas
        _canvas.addFontFace(FontLoader.load(app.resources.getText("fonts/gohu11.json")));
        _canvas.addFontFace(FontLoader.load(app.resources.getText("fonts/nokia.json")));
        _canvas.setTint(0.588, 0.690, 0.518);
        _canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(_canvas);

        _buildUI();
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        if (app.input.keyboard.released(ScanCode.ESCAPE))
            app.switchToStateByName("Menu");
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (_canvas != null) _canvas.resize(width, height);
    }

    // ── UI construction ───────────────────────────────────────────────────────

    private function _buildUI():Void {
        var ws = app.window.size;

        // ── Menu bar ──────────────────────────────────────────────────────────
        var menu = new Toolstripmenu();
        menu.addItem("File", ["Open TTF", "Export", "Back"], _onFileMenu);
        menu.addItem("Bake", ["Bake All"],                   _onBakeMenu);
        _canvas.addControl(menu);

        // ── Left panel — font list + editor ──────────────────────────────────
        var panelH:Float = ws.y - MENU_H - MARGIN * 2;
        var panel = new Window("Fonts", OPTIONS_W, panelH,
                               MARGIN, MENU_H + MARGIN);
        _canvas.addControl(panel);

        // Scrollable list of added fonts
        _listContainer = new ScrollableContainer(OPTIONS_W - 16, 82, 8, 26);
        panel.addControl(_listContainer);

        // Add / Remove buttons
        var btnAdd = new Button("Add", 56, 8, 108);
        btnAdd.addListener(function(_, _) { _addEntry(); }, LEFT_CLICK);
        panel.addControl(btnAdd);

        var btnRemove = new Button("Remove", 72, 72, 108);
        btnRemove.addListener(function(_, _) { _removeSelected(); }, LEFT_CLICK);
        panel.addControl(btnRemove);

        // Separator label
        panel.addControl(new Label("── Selected font ──────────", 8, 138));

        // Path field
        panel.addControl(new Label("Path:", 8, 158));
        _pathField = new TextField("", OPTIONS_W - 16, 8, 174);
        _pathField.maxCharacters = 260;
        panel.addControl(_pathField);

        // Size field
        panel.addControl(new Label("Size (px):", 8, 202));
        _sizeField = new TextField("" + DEFAULT_SIZE, 52, 8, 218);
        _sizeField.restriction = "0123456789";
        _sizeField.maxCharacters = 4;
        panel.addControl(_sizeField);

        // Name field
        panel.addControl(new Label("Name:", 8, 246));
        _nameField = new TextField("", OPTIONS_W - 16, 8, 262);
        panel.addControl(_nameField);

        // Apply button — write field values back to the selected entry
        var btnApply = new Button("Apply", 60, 8, 296);
        btnApply.addListener(function(_, _) { _applyEdits(); }, LEFT_CLICK);
        panel.addControl(btnApply);

        // Atlas size dropdown
        panel.addControl(new Label("Atlas size:", 8, 332));
        _atlasDropdown = new Dropdown(100, 8, 348);
        _atlasDropdown.addItem("256");
        _atlasDropdown.addItem("512");
        _atlasDropdown.addItem("1024");
        _atlasDropdown.addItem("2048");
        _atlasDropdown.selectIndex(1); // default 512
        panel.addControl(_atlasDropdown);

        // ── Main area — atlas preview + status ───────────────────────────────
        var mainX:Float = OPTIONS_W + MARGIN * 2;
        var mainY:Float = MENU_H + MARGIN;
        var mainW:Float = ws.x - mainX - MARGIN;
        var mainH:Float = ws.y - mainY - MARGIN;

        _statusLabel = new Label("Add fonts and click Bake → Bake All.", mainX, mainY + 4);
        _canvas.addControl(_statusLabel);

        _atlasView = new ImageView(mainW, mainH - 20, mainX, mainY + 20);
        _canvas.addControl(_atlasView);
    }

    // ── Entry management ──────────────────────────────────────────────────────

    private function _addEntry():Void {
        _entries.push({ path: "", size: DEFAULT_SIZE, name: "font" + _entries.length });
        _rebuildList();
        _selectEntry(_entries.length - 1);
    }

    private function _removeSelected():Void {
        if (_selectedIdx < 0 || _selectedIdx >= _entries.length) return;
        _entries.splice(_selectedIdx, 1);
        _rebuildList();
        _selectEntry(_entries.length > 0 ? Std.int(Math.min(_selectedIdx, _entries.length - 1)) : -1);
    }

    private function _applyEdits():Void {
        if (_selectedIdx < 0 || _selectedIdx >= _entries.length) return;
        var e = _entries[_selectedIdx];
        e.path = StringTools.trim(_pathField.text);
        var sz = Std.parseInt(StringTools.trim(_sizeField.text));
        e.size = (sz != null && sz > 0) ? sz : DEFAULT_SIZE;
        var n = StringTools.trim(_nameField.text);
        e.name = n.length > 0 ? n : e.name;
        _rebuildList();
        _selectEntry(_selectedIdx);
        _statusLabel.text = 'Entry updated: ${e.name} @ ${e.size}px';
    }

    private function _selectEntry(idx:Int):Void {
        _selectedIdx = idx;
        if (idx >= 0 && idx < _entries.length) {
            var e = _entries[idx];
            _pathField.text = e.path;
            _sizeField.text = Std.string(e.size);
            _nameField.text = e.name;
        } else {
            _pathField.text = "";
            _sizeField.text = Std.string(DEFAULT_SIZE);
            _nameField.text = "";
        }
    }

    private function _rebuildList():Void {
        while (!_listContainer.controls.isEmpty()) {
            _listContainer.removeControl(_listContainer.controls.first());
        }
        for (i in 0..._entries.length) {
            var e = _entries[i];
            var lbl = new Label(e.name + "  " + e.size + "px", 0, i * LIST_ITEM_H);
            var capturedIdx = i;
            lbl.addListener(function(_, _) { _selectEntry(capturedIdx); }, LEFT_CLICK);
            _listContainer.addControl(lbl);
        }
    }

    // ── Menu handlers ─────────────────────────────────────────────────────────

    private function _onFileMenu(option:String):Void {
        switch (option) {
            case "Open TTF": _onOpen();
            case "Export":   _onExport();
            case "Back":     _onBack();
        }
    }

    private function _onBakeMenu(option:String):Void {
        _onBakeAll();
    }



    // ── Actions ───────────────────────────────────────────────────────────────

    private function _onOpen():Void {
        var path = NativeDialog.openFontFile();
        if (path == null) return;

        // Auto-derive name from filename
        var lastSlash = Std.int(Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\")));
        var baseName  = path.substring(lastSlash + 1);
        var dotPos    = baseName.lastIndexOf(".");
        var fontName  = dotPos > 0 ? baseName.substring(0, dotPos) : baseName;

        if (_selectedIdx >= 0 && _selectedIdx < _entries.length) {
            // Fill the selected entry
            _entries[_selectedIdx].path = path;
            _entries[_selectedIdx].name = fontName;
            _selectEntry(_selectedIdx);
            _rebuildList();
        } else {
            // No selection — create a new entry
            _entries.push({ path: path, size: DEFAULT_SIZE, name: fontName });
            _rebuildList();
            _selectEntry(_entries.length - 1);
        }
        _statusLabel.text = "Ready: " + path;
    }

    private function _onBakeAll():Void {
        if (_entries.length == 0) {
            _statusLabel.text = "Add at least one font entry first.";
            return;
        }

        // Validate all entries
        var bakeEntries = [];
        for (e in _entries) {
            var path = StringTools.trim(e.path);
            if (path.length == 0) {
                _statusLabel.text = 'Entry "${e.name}" has no path — set a TTF path first.';
                return;
            }
            #if sys
            if (!sys.FileSystem.exists(path)) {
                _statusLabel.text = 'File not found: $path';
                return;
            }
            bakeEntries.push({
                bytes: sys.io.File.getBytes(path),
                name:  e.name,
                size:  (e.size : Float),
                firstChar: null,
                numChars:  null
            });
            #end
        }

        var atlasSize = Std.parseInt(_atlasDropdown.selectedValue);
        if (atlasSize == null || atlasSize <= 0) atlasSize = 512;

        #if sys
        trace('FontBakerState: baking ${bakeEntries.length} font(s) into ${atlasSize}x${atlasSize} atlas');

        _bakedFont = FontBaker.bakeMultiple(bakeEntries, atlasSize, atlasSize);

        _atlasView.setPixels(cast _bakedFont.textureData.bytes, atlasSize, atlasSize, 4);

        var names = [for (f in _bakedFont.faces) '${f.fontName} ${f.fontSize}px'];
        _statusLabel.text = 'Baked: ' + names.join(", ") + '  (${atlasSize}x${atlasSize})';
        #end
    }

    private function _onExport():Void {
        if (_bakedFont == null) {
            _statusLabel.text = "Nothing to export — bake first.";
            return;
        }
        #if sys
        var outDir = "export";
        if (!sys.FileSystem.exists(outDir))
            sys.FileSystem.createDirectory(outDir);
        var atlasName = _bakedFont.faces.length == 1
            ? _bakedFont.fontName + "_" + _bakedFont.fontSize
            : "font_atlas";
        _bakedFont.exportAllFaces(outDir, atlasName);
        _statusLabel.text = "Exported " + _bakedFont.faces.length + " face(s) to " + outDir + "/";
        #end
    }

    private function _onBack():Void {
        app.switchToStateByName("Menu");
    }
}
