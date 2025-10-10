package states;

import State;
import App;
import Entity;
import display.Text;

/**
 * Test state to demonstrate bitmap font text rendering using TilemapFast
 */
class TextTestState extends State {
    
    private var helloText:Text;
    private var dynamicText:Text;
    private var helloEntity:Entity;
    private var dynamicEntity:Entity;
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
        
        // Create or get the text shader program (using dedicated text shader for bitmap fonts)
        var textVertShader = app.resources.getText("shaders/text.vert");
        var textFragShader = app.resources.getText("shaders/text.frag");
        var textProgramInfo = renderer.createProgramInfo("Text", textVertShader, textFragShader);
        
        if (textProgramInfo == null) {
            trace("Error: Failed to create text shader program");
            return;
        }
        
        trace("TextTestState: Camera ortho: " + camera.ortho);
        trace("TextTestState: Text positions - Hello: (50, 100), Dynamic: (50, 150)");
        
        // Create static hello world text
        helloText = new Text(textProgramInfo, app.resources, renderer, "nokiafc22", "Hello World!", 1.0);
        helloText.x = 10;    // Position closer to origin
        helloText.y = 10;    // Position closer to origin
        helloText.color = [1.0, 0.0, 0.0, 1.0];  // Bright red for visibility
        
        // Create dynamic text that will change
        dynamicText = new Text(textProgramInfo, app.resources, renderer, "nokiafc22", "Frame: 0", 1.0);
        dynamicText.x = 10;  // Position closer to origin
        dynamicText.y = 30;  // Below hello text
        dynamicText.color = [0.0, 1.0, 0.0, 1.0];  // Bright green for visibility
        
        // Create entities and add to the scene
        helloEntity = new Entity("hello_text", helloText);
        dynamicEntity = new Entity("dynamic_text", dynamicText);
        
        addEntity(helloEntity);
        addEntity(dynamicEntity);
        
        trace("TextTestState: Created text displays");
        trace("  Hello text: '" + helloText.text + "' at (" + helloText.x + ", " + helloText.y + ")");
        trace("  Dynamic text: '" + dynamicText.text + "' at (" + dynamicText.x + ", " + dynamicText.y + ")");
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