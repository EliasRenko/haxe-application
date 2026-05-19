package states;

import gui.Button;
import gui.Canvas;
import gui.Control;
import gui.ControlEventType;
import gui.Dropdown;
import gui.ImageView;
import gui.Label;
import gui.List as GUIList;
import gui.TextField;
import gui.Toolstripmenu;
import gui.Window;
import loaders.FontLoader;
import loaders.TGAExporter;
import Scancode;
import utils.NativeDialog;
import utils.TexturePacker;

/**
 * PackerState - Texture Atlas Packer tool.
 *
 * Workflow:
 *   1. Add image files via File → Open Image (or the "Add" button).
 *      Each image name defaults to its filename without extension; rename
 *      it in the Name field and click Apply.
 *   2. Pick an atlas size from the dropdown.
 *   3. Click Pack → Pack All to pack all images and preview the atlas.
 *   4. Enter an export name, then File → Export.
 *      Writes  <exe-dir>/export/<name>.tga  and  <name>.json.
 *   5. File → Back (or ESCAPE) to return to the menu.
 *
 * JSON format (same atlas file, one entry per source image):
 * {
 *   "atlas":   "my_atlas.tga",
 *   "width":   512,
 *   "height":  512,
 *   "regions": [
 *     { "name": "button", "x": 0, "y": 0, "width": 32, "height": 32 },
 *     ...
 *   ]
 * }
 */
class PackerState extends State {

    // ── Layout constants ──────────────────────────────────────────────────────
    private static inline var MENU_H:Int    = 24;
    private static inline var OPTIONS_W:Int = 240;
    private static inline var MARGIN:Int    = 4;

    // ── GUI references ────────────────────────────────────────────────────────
    private var _canvas:Canvas;
    private var _imageList:GUIList<Label>;
    private var _nameField:TextField;
    private var _atlasNameField:TextField;
    private var _atlasDropdown:Dropdown;
    private var _atlasView:ImageView;
    private var _statusLabel:Label;

    // ── Image entries ─────────────────────────────────────────────────────────
    private var _entries:Array<{ path:String, name:String }> = [];
    private var _selectedIdx:Int = -1;

    // ── Last pack result ──────────────────────────────────────────────────────
    private var _packResult:Null<PackResult> = null;

    // ─────────────────────────────────────────────────────────────────────────

    public function new(app:App) {
        super("Packer", app);
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
            app.resources.getTexture("textures/gui_debug.tga"));
        var fontTexture = renderer.uploadTexture(
            app.resources.getTexture("textures/font_atlas.tga"));
        var fontData = FontLoader.load(
            app.resources.getText("fonts/gohu14.json"));

        var ws = app.window.size;
        _canvas = new Canvas(this, ws.x, ws.y);
        _canvas.initializeGraphics(renderer, spriteTexture, fontTexture, fontData);
        _canvas.addFontFace(FontLoader.load(app.resources.getText("fonts/gohu11.json")));
        _canvas.addFontFace(FontLoader.load(app.resources.getText("fonts/nokia.json")));
        _canvas.setTint(0.588, 0.690, 0.518);
        _canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(_canvas);

        _buildUI();

        trace("PackerState: initialized");
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        if (app.input.keyboard.released(Scancode.ESCAPE))
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
        menu.addItem("File", ["Open Image", "Export", "Back"], _onFileMenu);
        menu.addItem("Pack", ["Pack All"],                     _onPackMenu);
        _canvas.addControl(menu);

        // ── Left panel ────────────────────────────────────────────────────────
        var panelH:Float = ws.y - MENU_H - MARGIN * 2;
        var panel = new Window("Images", OPTIONS_W, panelH,
                               MARGIN, MENU_H + MARGIN);
        _canvas.addControl(panel);

        // Scrollable list of added images
        _imageList = new GUIList<Label>(OPTIONS_W - 16, 8, 26);
        _imageList.addListener(_onListItemClick, ON_ITEM_CLICK);
        panel.addControl(_imageList);

        // Add / Remove buttons
        var btnAdd = new Button("Add", 56, 8, 108);
        btnAdd.addListener(function(_, _) { _onOpen(); }, LEFT_CLICK);
        panel.addControl(btnAdd);

        var btnRemove = new Button("Remove", 72, 72, 108);
        btnRemove.addListener(function(_, _) { _removeSelected(); }, LEFT_CLICK);
        panel.addControl(btnRemove);

        // ── Selected entry editor ─────────────────────────────────────────────
        panel.addControl(new Label("── Selected image ──────────", 8, 138));

        panel.addControl(new Label("Name:", 8, 158));
        _nameField = new TextField("", OPTIONS_W - 16, 8, 174);
        _nameField.maxCharacters = 64;
        panel.addControl(_nameField);

        var btnApply = new Button("Apply", 60, 8, 208);
        btnApply.addListener(function(_, _) { _applyName(); }, LEFT_CLICK);
        panel.addControl(btnApply);

        // ── Atlas settings ────────────────────────────────────────────────────
        panel.addControl(new Label("Atlas size:", 8, 244));
        _atlasDropdown = new Dropdown(100, 8, 260);
        _atlasDropdown.addItem("256");
        _atlasDropdown.addItem("512");
        _atlasDropdown.addItem("1024");
        _atlasDropdown.addItem("2048");
        _atlasDropdown.selectIndex(1); // default 512
        panel.addControl(_atlasDropdown);

        // Export name
        panel.addControl(new Label("Export name:", 8, 296));
        _atlasNameField = new TextField("atlas", OPTIONS_W - 16, 8, 312);
        _atlasNameField.maxCharacters = 64;
        panel.addControl(_atlasNameField);

        // ── Atlas preview area ────────────────────────────────────────────────
        var mainX:Float = OPTIONS_W + MARGIN * 2;
        var mainY:Float = MENU_H + MARGIN;
        var mainW:Float = ws.x - mainX - MARGIN;
        var mainH:Float = ws.y - mainY - MARGIN;

        _statusLabel = new Label("Add images and click Pack → Pack All.", mainX, mainY + 4);
        _canvas.addControl(_statusLabel);

        _atlasView = new ImageView(mainW, mainH - 20, mainX, mainY + 20);
        _canvas.addControl(_atlasView);
    }

    // ── Menu handlers ─────────────────────────────────────────────────────────

    private function _onFileMenu(option:String):Void {
        switch (option) {
            case "Open Image": _onOpen();
            case "Export":     _onExport();
            case "Back":       app.switchToStateByName("Menu");
        }
    }

    private function _onPackMenu(option:String):Void {
        _onPackAll();
    }

    // ── Entry management ──────────────────────────────────────────────────────

    private function _onOpen():Void {
        var paths = NativeDialog.openImageFiles();
        if (paths.length == 0) return;

        for (path in paths) {
            var lastSlash = Std.int(Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\")));
            var baseName  = path.substring(lastSlash + 1);
            var dotPos    = baseName.lastIndexOf(".");
            var imgName   = dotPos > 0 ? baseName.substring(0, dotPos) : baseName;
            _entries.push({ path: path, name: imgName });
        }

        _rebuildList();
        _selectEntry(_entries.length - 1);
        _statusLabel.text = paths.length == 1
            ? "Added: " + _entries[_entries.length - 1].name
            : "Added " + paths.length + " images";
    }

    private function _removeSelected():Void {
        if (_selectedIdx < 0 || _selectedIdx >= _entries.length) return;
        _entries.splice(_selectedIdx, 1);
        _rebuildList();
        _selectEntry(_entries.length > 0
            ? Std.int(Math.min(_selectedIdx, _entries.length - 1)) : -1);
    }

    private function _applyName():Void {
        if (_selectedIdx < 0 || _selectedIdx >= _entries.length) return;
        var n = StringTools.trim(_nameField.text);
        if (n.length > 0) {
            _entries[_selectedIdx].name = n;
            _rebuildList();
            _statusLabel.text = "Renamed to: " + n;
        }
    }

    private function _selectEntry(idx:Int):Void {
        _selectedIdx = idx;
        _nameField.text = (idx >= 0 && idx < _entries.length)
            ? _entries[idx].name
            : "";
    }

    private function _rebuildList():Void {
        while (!_imageList.controls.isEmpty())
            _imageList.removeControlAt(0);
        for (e in _entries)
            _imageList.addControl(new Label(e.name, 0, 0));
    }

    private function _onListItemClick(control:Control, type:UInt):Void {
        var idx = 0;
        for (c in _imageList.controls) {
            if (c == control) { _selectEntry(idx); return; }
            idx++;
        }
    }

    // ── Pack ──────────────────────────────────────────────────────────────────

    private function _onPackAll():Void {
        if (_entries.length == 0) {
            _statusLabel.text = "Add at least one image first.";
            return;
        }

        #if sys
        var atlasSize = Std.parseInt(_atlasDropdown.selectedValue);
        if (atlasSize == null || atlasSize <= 0) atlasSize = 512;

        trace('PackerState: packing ${_entries.length} image(s) into ${atlasSize}x${atlasSize}');

        _packResult = TexturePacker.pack(_entries, atlasSize, atlasSize);

        _atlasView.setPixels(cast _packResult.atlasData.bytes,
                             atlasSize, atlasSize, 4);

        var msg = 'Packed ${_packResult.regions.length} / ${_entries.length} image(s) into ${atlasSize}x${atlasSize}';
        if (_packResult.failed.length > 0)
            msg += "  |  Failed: " + _packResult.failed.join(", ");
        _statusLabel.text = msg;
        #end
    }

    // ── Export ────────────────────────────────────────────────────────────────

    private function _onExport():Void {
        if (_packResult == null) {
            _statusLabel.text = "Nothing to export — pack first.";
            return;
        }

        #if sys
        var exportName = StringTools.trim(_atlasNameField.text);
        if (exportName.length == 0) exportName = "atlas";

        var outDir = "export";
        if (!sys.FileSystem.exists(outDir))
            sys.FileSystem.createDirectory(outDir);

        // Write atlas TGA
        var tgaFile = exportName + ".tga";
        TGAExporter.saveToTGA(_packResult.atlasData, outDir + "/" + tgaFile);

        // Write JSON description
        var json = TexturePacker.toJson(_packResult, tgaFile);
        sys.io.File.saveContent(outDir + "/" + exportName + ".json", json);

        _statusLabel.text = 'Exported to $outDir/$exportName (.tga + .json)';
        trace('PackerState: exported to $outDir/$exportName');
        #end
    }
}
