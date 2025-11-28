package states;

import display.ManagedTileBatch;
import gui.Stamp;
import gui.Strip;
import gui.Panel;
import gui.Checkbox;
import gui.Button;
import State;
import App;
import Entity;
import Renderer;
import ProgramInfo;
import Texture;
import display.BitmapFont;
import display.TileBatch;
import loaders.FontLoader;
import comps.DisplayObjectComp;
import gui.Canvas;
import gui.Window;
/**
 * UI Test State - Testing UI components with Canvas
 */
class UITestState extends State {
    
    private var canvas:Canvas;

    var uiTileBatch:ManagedTileBatch;
    var bitmapFont:BitmapFont;
    
    public function new(app:App) {
        super("UITestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("UITestState: Initializing");
        
        // Setup camera for 2D
        camera.ortho = true;
        //camera.update();
        
        var renderer = app.renderer;
        
        // Setup UI canvas with graphics
        setupCanvas(renderer);
        
        trace("UITestState: Setup complete");
    }
    
    /**
     * Setup UI canvas with texture atlas and font
     */
    private function setupCanvas(renderer:Renderer):Void {
        // Load UI texture
        var uiTextureData = app.resources.getTexture("textures/gui.tga");
        if (uiTextureData == null) {
            trace("UITestState: Failed to load UI texture");
            return;
        }
        var uiTexture = renderer.uploadTexture(uiTextureData);
        trace("UITestState: GUI texture uploaded - " + uiTexture.width + "x" + uiTexture.height);
        
        // Create shader program for UI
        var vertShader = app.resources.getText("shaders/textured.vert");
        var fragShader = app.resources.getText("shaders/textured.frag");
        var programInfo = renderer.createProgramInfo("textured", vertShader, fragShader);
        
        // Create TileBatch for UI elements
        uiTileBatch = new ManagedTileBatch(programInfo, uiTexture);
        uiTileBatch.init(renderer);
        
        // Add UI batch to scene for rendering
        var uiEntity = new Entity("ui_batch");
        var uiDisplay = new DisplayObjectComp(uiTileBatch);
        uiEntity.addComponent(uiDisplay);
        addEntity(uiEntity);
        
        // Load font
        var fontData = FontLoader.load(app.resources.getText("fonts/gohu14.json"));
        if (fontData == null) {
            trace("UITestState: Failed to load font");
            return;
        }
        
        // Load font texture
        var fontTextureData = app.resources.getTexture("textures/gohu14.tga");
        if (fontTextureData == null) {
            trace("UITestState: Failed to load font texture");
            return;
        }
        var fontTexture = renderer.uploadTexture(fontTextureData);
        
        // Create shader program for text (mono shader for 1bpp fonts)
        var monoVertShader = app.resources.getText("shaders/mono.vert");
        var monoFragShader = app.resources.getText("shaders/mono.frag");
        var monoProgramInfo = renderer.createProgramInfo("mono", monoVertShader, monoFragShader);
        
        // Create BitmapFont (shared)
        bitmapFont = new BitmapFont(monoProgramInfo, fontTexture, fontData);
        bitmapFont.init(renderer);
        
        // Add font to scene for rendering
        var fontEntity = new Entity("bitmap_font");
        var fontDisplay = new DisplayObjectComp(bitmapFont);
        fontEntity.addComponent(fontDisplay);
        addEntity(fontEntity);
        
        // Create canvas
        canvas = new Canvas(this, 640, 480);
        canvas.initializeGraphics(uiTileBatch, bitmapFont);
        
        // Load UI texture atlas definitions
        var guiJson = app.resources.getText("textures/gui.json");
        if (guiJson != null) {
            canvas.importSets(guiJson);
        }
        
        addEntity(canvas);

        var button:Button = new Button("Click Me", 120, 16, 0);
        canvas.addControl(button);

        var checkBox:Checkbox = new Checkbox(true, 16, 30);
        canvas.addControl(checkBox);

        var strip:Strip = new Strip(120, 16, 60);
        canvas.addControl(strip);

        var stamp:Stamp = new Stamp(26, 0, 150);
        canvas.addControl(stamp);

        var panel:Panel = new Panel(120, 120, 150, 0);
        canvas.addControl(panel);

        var window:Window = new Window("Test", 120, 120, 150, 150);
        canvas.addControl(window);

        trace("UITestState: Canvas setup complete");
        trace("UITestState: UI TileBatch has " + uiTileBatch.getTileCount() + " tiles");
        trace("UITestState: BitmapFont has " + bitmapFont.getTileCount() + " tiles");
    }
    
    override public function update(deltaTime:Float):Void {
        // Update entities
        for (entity in entities) {
            if (entity != null && entity.active) {
                entity.update(deltaTime);
            }
        }
        
        // Late update all entities
        for (entity in entities) {
            if (entity != null && entity.active) {
                entity.lateUpdate(deltaTime);
            }
        }
    }

    override public function render(renderer:Renderer):Void {
        super.render(renderer);

        canvas.render(renderer, camera.getMatrix());
    }

    override public function onWindowResized(width:Int, height:Int):Void {
        super.onWindowResized(width, height);
        
        if (canvas != null) {
            canvas.resize(width, height);
        }
    }
}
