package states;

import State;
import App;
import Entity;
import display.Text;
import loaders.FontLoader;
import loaders.FontData;

/**
 * Test state to demonstrate bitmap font text rendering
 */
class TextTestState extends State {
    
    private var helloText:Text;
    private var dynamicText:Text;
    private var frameCount:Int = 0;
    
    public function new(app:App) {
        super("TextTestState", app);
    }
    
    override public function init():Void {
        super.init();
        trace("TextTestState activated - creating text rendering test");
        
        // Set up orthographic camera for 2D text
        camera.ortho = true;
        
        createTextTest();
    }
    
    private function createTextTest():Void {
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Create mono shader program for 1bpp font texture
        var monoVertShader = app.resources.getText("shaders/mono.vert");
        var monoFragShader = app.resources.getText("shaders/mono.frag");
        var monoProgramInfo = renderer.createProgramInfo("Mono", monoVertShader, monoFragShader);
        
        if (monoProgramInfo == null) {
            trace("Error: Failed to create mono shader program");
            return;
        }
        
        // Load font JSON
        var fontJson = app.resources.getText("fonts/gohu.json");
        if (fontJson == null) {
            trace("Error: Could not load gohu.json!");
            return;
        }
        
        // Parse font data
        var fontData = FontLoader.load(fontJson);
        
        // Load font texture
        var fontTextureData = app.resources.getTexture("textures/gohu.tga");
        if (fontTextureData == null) {
            trace("Error: Could not load gohu.tga texture!");
            return;
        }
        
        // Upload texture to GPU
        var fontTexture = renderer.uploadTexture(fontTextureData);
        trace("Uploaded font texture: " + fontTexture.width + "x" + fontTexture.height);
        
        trace("TextTestState: Camera ortho: " + camera.ortho);
        
        // Create static hello world text
        helloText = new Text(monoProgramInfo, fontTexture, fontData);
        helloText.x = 10;
        helloText.y = 10;
        helloText.setText("Hello World!");
        
        // Create dynamic text that will change
        dynamicText = new Text(monoProgramInfo, fontTexture, fontData);
        dynamicText.x = 10;
        dynamicText.y = 50;
        dynamicText.setText("Frame: 0");
        
        // Create entities and add to the scene
        var helloEntity = new Entity("hello_text");
        addEntity(helloEntity);
        
        var dynamicEntity = new Entity("dynamic_text");
        addEntity(dynamicEntity);
        
        trace("TextTestState: Created text displays");
        trace("  Hello text: '" + helloText.getText() + "' at (" + helloText.x + ", " + helloText.y + ")");
        trace("  Dynamic text: '" + dynamicText.getText() + "' at (" + dynamicText.x + ", " + dynamicText.y + ")");
    }
    
    override public function update(dt:Float):Void {
        super.update(dt);
        
        frameCount++;
        
        // Update dynamic text every 60 frames (approximately 1 second at 60 FPS)
        if (frameCount % 60 == 0) {
            var seconds = Std.int(frameCount / 60);
            dynamicText.setText("Frame: " + frameCount + " (" + seconds + "s)");
        }
        
        // Add some simple text animation - make texts slowly move
        //helloText.x += Math.sin(frameCount * 0.01) * 0.1;
        //dynamicText.x += Math.cos(frameCount * 0.01) * 0.1;
    }
    
    override public function release():Void {
        trace("TextTestState: Cleaning up");
        super.release();
    }
}