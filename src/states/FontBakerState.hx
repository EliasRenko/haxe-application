package states;

import State;
import App;
import Renderer;
import utils.FontBaker;
import display.BitmapFont;
import display.Text;
import entity.DisplayEntity;
import loaders.FontLoader;

/**
 * FontBakerState - Test state for baking TrueType fonts to bitmap atlases
 * 
 * This state demonstrates using stb_truetype to generate font atlases
 * from .ttf files. The baked fonts can then be used with the existing
 * BitmapFont/Text rendering system.
 */
class FontBakerState extends State {
    
    private var bitmapFont:BitmapFont;
    private var displayText:Text;
    private var currentFontSize:Float = 20.0;
    
    public function new(app:App) {
        super("FontBakerState", app);
    }
    
    override public function init():Void {
        super.init();
        
        // Set up orthographic camera for 2D text rendering
        camera.ortho = true;
        
        // Bake font with initial size
        bakeFontAtSize(currentFontSize);
        
        // Now load and display the baked font immediately
        setupBakedFont(app.renderer);
        
        trace("");
        trace("Press ESC to exit");
        trace("Press P to increase font size");
        trace("Press O to decrease font size");
    }
    
    /**
     * Bake font at specified size
     */
    private function bakeFontAtSize(fontSize:Float):Void {
        var separator = "";
        for (i in 0...60) separator += "=";
        
        trace(separator);
        trace("FontBakerState: Baking font at " + fontSize + "px");
        trace(separator);
        
        // Bake Nokia FC22 font for pixel art rendering
        // Critical settings for pixel art:
        // - fontSize MUST match font's designed size (16px for Nokia FC22)
        // - No oversampling (1x1) - prevents anti-aliasing blur
        // - Binary threshold - converts to pure black/white
        // - GL_NEAREST filtering (already set in Renderer)
        // This will generate:
        //   - res/fonts/nokiafc22_baked.tga (atlas texture)
        //   - res/fonts/nokiafc22_baked.json (character metadata)
        FontBaker.bakeFont(
            "res/fonts/nokiafc22.ttf",  // Input TTF file
            "nokiafc22_baked",          // Output name (without extension)
            fontSize,                   // Font size in pixels
            512,                        // Atlas width
            512,                        // Atlas height
            32,                         // First character (space)
            96                          // Number of characters (ASCII printable)
        );
        
        trace(separator);
        trace("FontBakerState: Font baking complete!");
        trace(separator);
    }
    
    /**
     * Setup and display the baked font
     */
    private function setupBakedFont(renderer:Renderer):Void {
        trace("");
        trace("FontBakerState: Loading baked font for display...");
        
        // Load font JSON at runtime (not from cache)
        app.resources.loadText("fonts/nokiafc22_baked.json", false).then((jsonText) -> {
            var fontData = FontLoader.load(jsonText);
            
            // Load font texture at runtime (not from cache)
            app.resources.loadTexture("fonts/nokiafc22_baked.tga", false).then((fontTextureData) -> {
                var fontTexture = renderer.uploadTexture(fontTextureData);
                
                // Create mono shader for text
                var monoVertShader = app.resources.getText("shaders/mono.vert");
                var monoFragShader = app.resources.getText("shaders/mono.frag");
                var monoProgramInfo = renderer.createProgramInfo("mono_baked_font", monoVertShader, monoFragShader);
                
                trace("FontBakerState: DEBUG - Shader loaded: " + (monoProgramInfo != null));
                trace("FontBakerState: DEBUG - Font texture ID: " + fontTexture.id);
                trace("FontBakerState: DEBUG - Font texture size: " + fontTextureData.width + "x" + fontTextureData.height);
                trace("FontBakerState: DEBUG - Font data characters: " + Lambda.count(fontData.chars));
                
                // Create bitmap font
                bitmapFont = new BitmapFont(monoProgramInfo, fontTexture, fontData);
                bitmapFont.init(renderer);
                
                trace("FontBakerState: DEBUG - BitmapFont created, visible=" + bitmapFont.visible);
                
                // Create text to display
                var centerX = app.window.size.x / 2 - 150;
                var centerY = app.window.size.y / 2;
                
                trace("FontBakerState: DEBUG - Window size: " + app.window.size.x + "x" + app.window.size.y);
                trace("FontBakerState: DEBUG - Text position: (" + centerX + ", " + (centerY - 100) + ")");
                
                displayText = new Text(bitmapFont, 
                    "Hello, World!\nBaked Font Test\nNokia FC22 @ " + Std.int(currentFontSize) + "px\n\nABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789\n!@#$%^&*()_+-=[]{}|;':,\",./<>?",
                    centerX, 
                    centerY - 100
                );
                
                trace("FontBakerState: DEBUG - Text created, visible=" + displayText.visible);
                trace("FontBakerState: DEBUG - Text size: " + displayText.width + "x" + displayText.height);
                trace("FontBakerState: DEBUG - Tiles before buffer update: " + bitmapFont.getTileCount());
                trace("FontBakerState: DEBUG - Atlas regions defined: " + Lambda.count(bitmapFont.atlasRegions));
                
                // Update buffers after adding text tiles
                bitmapFont.needsBufferUpdate = true;
                bitmapFont.updateBuffers(renderer);
                
                trace("FontBakerState: DEBUG - Buffers updated");
                
                // Add font to scene using DisplayEntity (Text uses the font's tile batch)
                var fontEntity = new DisplayEntity(bitmapFont, "baked_font_display");
                addEntity(fontEntity);
                
                trace("FontBakerState: DEBUG - Entity created, active=" + fontEntity.active + ", visible=" + fontEntity.visible);
                trace("FontBakerState: DEBUG - DisplayObject visible=" + fontEntity.displayObject.visible);
                trace("FontBakerState: DEBUG - Total entities in state: " + entities.length);
                
                trace("FontBakerState: Baked font displayed successfully!");
                trace("FontBakerState: BitmapFont has " + bitmapFont.getTileCount() + " tiles");
            }).onError((error) -> {
                trace("FontBakerState: Failed to load font texture - " + error);
            });
        }).onError((error) -> {
            trace("FontBakerState: Failed to load font data - " + error);
        });
    }
    
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        // Check for ESC to exit
        if (app.input.keyboard.pressed(Keycode.ESCAPE)) { // ESC key
            trace("FontBakerState: Exiting...");
            #if sys
            Sys.exit(0);
            #end
        }
        
        // Check for P key to increase font size (scancode 19 = 'P')
        if (app.input.keyboard.pressed(Keycode.P)) {
            currentFontSize += 1.0;
            if (currentFontSize > 64.0) currentFontSize = 64.0; // Max size
            trace("FontBakerState: Increasing font size to " + currentFontSize + "px");
            rebakeFont();
        }
        
        // Check for O key to decrease font size (scancode 18 = 'O')
        if (app.input.keyboard.pressed(Keycode.O)) {
            currentFontSize -= 1.0;
            if (currentFontSize < 4.0) currentFontSize = 4.0; // Min size
            trace("FontBakerState: Decreasing font size to " + currentFontSize + "px");
            rebakeFont();
        }
    }
    
    /**
     * Rebake font and reload it
     */
    private function rebakeFont():Void {
        // Remove old font entity
        if (entities.length > 0) {
            var entity = entities[0];
            removeEntity(entity);
        }
        
        // Rebake font with new size
        bakeFontAtSize(currentFontSize);
        
        // Reload and display
        setupBakedFont(app.renderer);
    }
    
    private var renderFrameCount:Int = 0;
    
    override public function render(renderer:Renderer):Void {
        // Only log first 3 frames to reduce spam
        if (renderFrameCount < 3) {
            if (bitmapFont != null) {
                trace("FontBakerState: DEBUG RENDER - Font tiles: " + bitmapFont.getTileCount() + ", visible: " + bitmapFont.visible);
            }
            
            var renderCount = 0;
            for (entity in entities) {
                if (entity != null && entity.active && entity.visible) {
                    renderCount++;
                }
            }
            trace("FontBakerState: DEBUG RENDER - Rendering " + renderCount + "/" + entities.length + " entities");
            renderFrameCount++;
        }
        
        super.render(renderer);
    }
}
