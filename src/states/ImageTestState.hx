package states;

import State;
import App;
import Entity;
import Renderer;
import display.Image;

/**
 * A test state that demonstrates Image rendering
 */
class ImageTestState extends State {
    
    public function new(app:App) {
        super("ImageTestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("ImageTestState activated - creating image test");
        
        // Use camera at default position to understand baseline coordinate system
        camera.ortho = true;
        // Leave camera at default position (0,0,0) with default orientation
        
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Create ProgramInfo for image (uses textured shaders)
        var imageVertShader = app.resources.getText("shaders/textured.vert");
        var imageFragShader = app.resources.getText("shaders/textured.frag");
        var imageProgramInfo = renderer.createProgramInfo("Image", imageVertShader, imageFragShader);
        
        // Get a texture from preloaded resources
        var textureData = app.resources.getTexture("textures/dev1.tga");
        if (textureData == null) {
            trace("Error: Could not load dev1.tga texture!");
            return;
        }
        
        // Upload texture to GPU and get Texture object
        var texture = renderer.uploadTexture(textureData);
        
        // Create an image entity using texture dimensions automatically
        var imageDisplay = new Image(imageProgramInfo, texture);
        
        // Now with pixel-perfect camera, position image at center of screen
        // Screen size from App constants, so center is at (WINDOW_WIDTH/2, WINDOW_HEIGHT/2)
        // But we want to position by the image's top-left corner, so subtract half the image size
        imageDisplay.x = (__app.WINDOW_WIDTH / 2) - (texture.width / 2);   // Center horizontally 
        imageDisplay.y = (__app.WINDOW_HEIGHT / 2) - (texture.height / 2);  // Center vertically
        imageDisplay.z = 0.0;   // Default Z position
        
        // No scaling needed - image will render at 1:1 pixel size
        
        // Create entity and add to state
        var imageEntity = new Entity("image", imageDisplay);
        addEntity(imageEntity);
        
        // Add Nokia FC22 bitmap font texture as a second image
        var monoVertShader = app.resources.getText("shaders/mono.vert");
        var monoFragShader = app.resources.getText("shaders/mono.frag");
        var monoProgramInfo = renderer.createProgramInfo("Mono", monoVertShader, monoFragShader);
        
        // Get the Nokia FC22 bitmap font texture (1 BPP)
        var fontTextureData = app.resources.getTexture("textures/nokiafc22.tga");
        if (fontTextureData != null && monoProgramInfo != null) {
            var fontTexture = renderer.uploadTexture(fontTextureData);
            var fontDisplay = new Image(monoProgramInfo, fontTexture);
            
            // Position the font texture to the right of the main image
            fontDisplay.x = imageDisplay.x + texture.width + 20; // 20 pixel gap
            fontDisplay.y = imageDisplay.y; // Same vertical position
            fontDisplay.z = 0.0;
            
            // Create entity and add to state
            var fontEntity = new Entity("font", fontDisplay);
            addEntity(fontEntity);
            
            trace("Added Nokia FC22 font texture: " + fontTexture.width + "x" + fontTexture.height);
        } else {
            trace("Warning: Could not load Nokia FC22 font texture or create mono shader");
        }
        
        trace("ImageTestState setup complete - images created");
        trace("Camera configured: pixel-perfect orthographic (0,0 at top-left)");
        trace("Main image positioned at: " + imageDisplay.x + ", " + imageDisplay.y);
        trace("Window size: " + __app.WINDOW_WIDTH + "x" + __app.WINDOW_HEIGHT + " pixels");
    }
    
    override public function release():Void {
        super.release();
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Optional: Add some animation to the main image
        var imageEntity = getEntity("image");
        if (imageEntity != null && imageEntity.displayObject != null) {
            var image = cast(imageEntity.displayObject, Image);
            // Rotate the image slowly clockwise (positive values now rotate clockwise)
            image.rotationZ += 1.0 * deltaTime; // 1 degree per second clockwise
        }
        
        // Keep the font texture static for better visibility
        // var fontEntity = getEntity("font");
        // if (fontEntity != null) {
        //     // Font stays static to show bitmap characters clearly
        // }
    }
}
