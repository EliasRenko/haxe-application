package states;

import State;
import App;
import Entity;
import Renderer;
import display.Image;
import display.TileBatch;

/**
 * A test state that demonstrates Image rendering
 */
class ImageTestState extends State {
    
    public function new(app:App) {
        super("ImageTestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("=============================================");
        trace("IMAGETEST: ImageTestState activated - creating image test");
        trace("=============================================");
        
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
            //addEntity(fontEntity);
            
            trace("Added Nokia FC22 font texture: " + fontTexture.width + "x" + fontTexture.height);
        } else {
            trace("Warning: Could not load Nokia FC22 font texture or create mono shader");
        }
        
        // Add TileBatch example using dev_tiles.tga
        var tilesTextureData = app.resources.getTexture("textures/dev_tiles.tga");
        trace("DEBUG: tilesTextureData = " + tilesTextureData);
        if (tilesTextureData != null) {
            trace("DEBUG: tilesTextureData size = " + tilesTextureData.width + "x" + tilesTextureData.height + ", BPP=" + tilesTextureData.bytesPerPixel);
        }
        if (tilesTextureData != null && imageProgramInfo != null) {
            var tilesTexture = renderer.uploadTexture(tilesTextureData);
            trace("DEBUG: Uploaded tilesTexture ID = " + tilesTexture.id + ", size = " + tilesTexture.width + "x" + tilesTexture.height);
            
            // Create TileBatch using the regular textured shader
            var tileBatch = new TileBatch(imageProgramInfo, tilesTexture);
            
            // Position TileBatch below the other images
            tileBatch.x = 50;  // Left side of screen
            tileBatch.y = 300; // Below other content
            tileBatch.z = 0.0;
            
            // Define regions for the 6 tiles in dev_tiles.tga (128x128 texture)
            // The actual tile content is in the top portion (as shown in texture preview)
            var regionIds = [];
            
            // Define 6 regions in the top area where the actual tiles are (3x2 grid starting at y=0)
            var positions = [
                {x: 0, y: 0},      // Top row, left
                {x: 32, y: 0},     // Top row, center
                {x: 64, y: 0},     // Top row, right
                {x: 0, y: 32},     // Second row, left
                {x: 32, y: 32},    // Second row, center  
                {x: 64, y: 32}     // Second row, right
            ];
            
            for (i in 0...6) {
                var pos = positions[i];
                var regionId = tileBatch.defineRegion(pos.x, pos.y, 32, 32);
                regionIds.push(regionId);
                trace("DEBUG: Defined region " + regionId + " for tile " + i + " at atlas (" + pos.x + "," + pos.y + ") size=32x32");
            }
            
            // Display all 6 tiles in a horizontal row
            var displayTileSize = 32; // Display size in world units
            var spacing = 8;          // Gap between tiles
            for (i in 0...regionIds.length) {
                var tileX = i * (displayTileSize + spacing);
                var tileY = 0;
                var tileId = tileBatch.addTile(tileX, tileY, displayTileSize, displayTileSize, regionIds[i]);
                trace("DEBUG: Added display tile " + tileId + " at (" + tileX + "," + tileY + ") using region " + regionIds[i]);
            }
            
            // Add a full texture tile below for reference
            var fullTextureRegion = tileBatch.defineRegion(0, 0, 128, 128); // Full 128x128 texture
            var fullTileX = 0;
            var fullTileY = -80; // Position below the individual tiles
            var fullTileId = tileBatch.addTile(fullTileX, fullTileY, 64, 64, fullTextureRegion);
            trace("DEBUG: Added full texture tile " + fullTileId + " at (" + fullTileX + "," + fullTileY + ") for reference");
            
            // Create entity and add to state
            var tileBatchEntity = new Entity("tilebatch", tileBatch);
            addEntity(tileBatchEntity);
            
            trace("Added TileBatch: " + tileBatch.getTileCount() + " tiles from dev_tiles.tga (" + tilesTexture.width + "x" + tilesTexture.height + ")");
        } else {
            trace("Warning: Could not load dev_tiles.tga texture or create shader program");
        }
        
        // trace("ImageTestState setup complete - images created");
        // trace("Camera configured: pixel-perfect orthographic (0,0 at top-left)");
        // trace("Main image positioned at: " + imageDisplay.x + ", " + imageDisplay.y);
        // trace("Window size: " + __app.WINDOW_WIDTH + "x" + __app.WINDOW_HEIGHT + " pixels");
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
