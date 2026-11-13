package states;

import gui.Control;
import utils.NativeDialog;
import gui.Button;
import gui.Label;
import gui.ScrollableContainer;
import gui.Toolstripmenu;
import gui.Canvas;
import loaders.FontLoader;
import gui.Window;
import gui.ControlEventType;

class FontEditor extends State {

    private static inline var MENU_H:Int = 24;
    private static inline var OPTIONS_W:Int = 240;
    private static inline var MARGIN:Int = 4;
    private static inline var DEFAULT_SIZE:Int = 16;
    private static inline var LIST_ITEM_H:Int = 20;

    // Privates
    private var _canvas:Canvas;
    private var _listContainer:ScrollableContainer;

    private var entries:Array<{ path:String, size:Int, name:String }> = [];
    private var _selectedIdx:Int = -1;

    public function new(app:App) {
        super("FontEditor", app);
    }

    override public function init():Void {
        super.init();
        camera.ortho = true;

        var renderer = app.renderer;
        var spriteTexture = renderer.uploadTexture(app.resources.getTexture("textures/gui.tga"));
        var fontTexture = renderer.uploadTexture(app.resources.getTexture("textures/font_atlas.tga"));
        var fontData = FontLoader.load(app.resources.getText("fonts/gohu14.json"));
        var ws = app.window.size;

        _canvas = new Canvas(this, ws.x, ws.y);
        _canvas.initializeGraphics(renderer, spriteTexture, fontTexture, fontData);
        _canvas.addFontFace(FontLoader.load(app.resources.getText("fonts/gohu11.json")));
        _canvas.addFontFace(FontLoader.load(app.resources.getText("fonts/nokia.json")));
        _canvas.setTint(0.588, 0.690, 0.518);
        _canvas.importSets(app.resources.getText("textures/gui.json"));
        addEntity(_canvas);

        buildUI();
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        if (_canvas != null) _canvas.resize(width, height);
    }

    private function buildUI():Void {
        var ws = app.window.size;

        // Menu bar
        var menu = new Toolstripmenu();
        menu.addItem("File", ["Open TTF", "Export", "Back"], onFileMenu);
        menu.addItem("Bake", ["Bake All"], onBakeMenu);
        _canvas.addControl(menu);

        // Left panel - font list + editor
        var panelH:Float = ws.y - MENU_H - MARGIN * 2;
        var panel = new Window("Editor", OPTIONS_W, panelH, MARGIN, MENU_H + MARGIN);
        _canvas.addControl(panel);

        // Font label
        var fontLabel:Label = new Label("Imported fonts", 4, 4);
        panel.addControl(fontLabel);

        // Scrollable list of added fonts
        _listContainer = new ScrollableContainer(OPTIONS_W - 16, 82, 8, 26);
        panel.addControl(_listContainer);

        // Add font button
        var addFontButton:Button = new Button("Add font", 80, 4, 116);
        addFontButton.addListener(openFont, ControlEventType.LEFT_CLICK);
        panel.addControl(addFontButton);

        // Remove font button
        var removeFontButton:Button = new Button("Remove font", 80, 88, 116);
        panel.addControl(removeFontButton);
    }

    private function onFileMenu(option:String):Void {
        
    }

    private function onBakeMenu(option:String):Void {
        
    }

    private function openFont(control:Control, type:Int):Void {
        var path = NativeDialog.openFontFile();
        if (path == null) return;

        // Auto-derive name from filename
        var lastSlash = Std.int(Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\")));
        var baseName  = path.substring(lastSlash + 1);
        var dotPos    = baseName.lastIndexOf(".");
        var fontName  = dotPos > 0 ? baseName.substring(0, dotPos) : baseName;

        if (_selectedIdx >= 0 && _selectedIdx < entries.length) {
            // Fill the selected entry
            entries[_selectedIdx].path = path;
            entries[_selectedIdx].name = fontName;
            selectEntry(_selectedIdx);
            rebuildList();
        } else {
            // No selection — create a new entry
            entries.push({ path: path, size: DEFAULT_SIZE, name: fontName });
            rebuildList();
            selectEntry(entries.length - 1);
        }
        //_statusLabel.text = "Ready: " + path;
    }

    private function selectEntry(idx:Int):Void {
        _selectedIdx = idx;
        if (idx >= 0 && idx < entries.length) {
            var e = entries[idx];
            // _pathField.text = e.path;
            // _sizeField.text = Std.string(e.size);
            // _nameField.text = e.name;
        } else {
            // _pathField.text = "";
            // _sizeField.text = Std.string(DEFAULT_SIZE);
            // _nameField.text = "";
        }
    }

    private function rebuildList():Void {
        while (!_listContainer.controls.isEmpty()) {
            _listContainer.removeControl(_listContainer.controls.first());
        }
        for (i in 0...entries.length) {
            var e = entries[i];
            var lbl = new Label(e.name + "  " + e.size + "px", 0, i * LIST_ITEM_H);
            var capturedIdx = i;
            lbl.addListener(function(_, _) { selectEntry(capturedIdx); }, LEFT_CLICK);
            _listContainer.addControl(lbl);
        }
    }
}