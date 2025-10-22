package states;

import State;
import App;
import gui.Canvas;
import gui.Button;
import gui.Label;
import gui.Control;

/**
 * CanvasTestState - Test state for Canvas UI system
 * 
 * Demonstrates:
 * - Canvas initialization
 * - UI atlas loading
 * - Button and Label controls
 * - Mouse input handling
 * - Focus management
 */
class CanvasTestState extends State {
    
    private var canvas:Canvas;
    private var testButton1:Button;
    private var testButton2:Button;
    private var testLabel:Label;
    
    public function new(app:App) {
        super("CanvasTestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("======================================");
        trace("CanvasTestState: Initializing UI test");
        trace("======================================");
        
        // Set up orthographic camera for 2D UI
        camera.ortho = true;
        camera.x = 0;
        camera.y = 0;
        camera.z = 1.0;
        
        createCanvasTest();
    }
    
    private function createCanvasTest():Void {
        // Create Canvas entity
        canvas = new Canvas(this, app.WINDOW_WIDTH, app.WINDOW_HEIGHT);
        addEntity(canvas);
        
        // Initialize Canvas (creates TileBatchFast)
        canvas.init();
        
        // Load UI atlas from gui.tga and gui.json
        trace("CanvasTestState: Loading UI atlas...");
        canvas.loadUIAtlas("textures/gui.tga", "text/gui.json");
        
        // Create test button 1
        trace("CanvasTestState: Creating test controls...");
        testButton1 = new Button("Click Me!", 100, 100, 120, 40);
        canvas.addControl(testButton1);
        
        // Add click listener to button 1
        testButton1.addListener(function(control:Control, type:UInt) {
            trace("Button 1 clicked!");
        }, gui.events.ControlEventType.LEFT_CLICK);
        
        // Create test button 2
        testButton2 = new Button("Button 2", 100, 160, 120, 40);
        canvas.addControl(testButton2);
        
        // Add click listener to button 2
        testButton2.addListener(function(control:Control, type:UInt) {
            trace("Button 2 clicked!");
        }, gui.events.ControlEventType.LEFT_CLICK);
        
        // Create test label
        testLabel = new Label("Canvas UI Test", 100, 220, false);
        canvas.addControl(testLabel);
        
        trace("CanvasTestState: Created " + testButton1.type + ", " + testButton2.type + ", and " + testLabel.type);
        trace("CanvasTestState: Canvas size: " + canvas.width + "x" + canvas.height);
        trace("CanvasTestState: Mouse input test - click the buttons!");
        trace("======================================");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Canvas update is handled by Entity.update() in State
        // which calls canvas.update() automatically
    }

    override function render(renderer:Dynamic) {
        super.render(renderer);
    }
}
