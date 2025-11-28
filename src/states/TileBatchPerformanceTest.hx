package states;

import State;
import App;
import Entity;
import Renderer;
import ProgramInfo;
import Texture;
import display.TileBatch;
import display.Tile;
import display.BitmapFont;
import display.Text;
import comps.DisplayObjectComp;
import loaders.FontLoader;

/**
 * TileBatch Performance Test - 1000 moving tiles
 * Tests orphaning strategy performance with maximum tile capacity
 */
class TileBatchPerformanceTest extends State {
    
    private var tileBatch:TileBatch;
    private var tileData:Array<Tile> = [];
    private var tileVelocities:Array<{vx:Float, vy:Float}> = [];
    
    private var bitmapFont:BitmapFont;
    private var fpsText:Text;
    private var fpsUpdateTimer:Float = 0.0;
    private var currentFps:Int = 0;
    
    private static inline var TILE_COUNT:Int = 1000;
    private static inline var TILE_SIZE:Float = 16.0;
    private static inline var MIN_SPEED:Float = 50.0;
    private static inline var MAX_SPEED:Float = 150.0;
    private static inline var FPS_UPDATE_INTERVAL:Float = 0.25; // Update FPS display 4 times per second
    
    private var screenWidth:Float;
    private var screenHeight:Float;
    
    public function new(app:App) {
        super("TileBatchPerformanceTest", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("TileBatchPerformanceTest: Initializing 1000 moving tiles");
        
        // Setup camera for 2D
        camera.ortho = true;
        
        var size = app.window.size;
        
        var renderer = app.renderer;
        
        // Load texture atlas
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("TileBatchPerformanceTest: Failed to load texture");
            return;
        }
        var texture = renderer.uploadTexture(textureData);
        trace("TileBatchPerformanceTest: Texture uploaded - " + texture.width + "x" + texture.height);
        
        // Create shader program
        var vertShader = app.resources.getText("shaders/textured.vert");
        var fragShader = app.resources.getText("shaders/textured.frag");
        var programInfo = renderer.createProgramInfo("textured", vertShader, fragShader);
        
        // Create TileBatch
        tileBatch = new TileBatch(programInfo, texture);
        tileBatch.init(renderer);
        
        // Add to scene
        var entity = new Entity("tile_batch");
        var displayComp = new DisplayObjectComp(tileBatch);
        entity.addComponent(displayComp);
        addEntity(entity);
        
        // Define a single atlas region (using a small portion of the texture)
        var regionId = tileBatch.defineRegion(0, 0, 32, 32);
        
        // Create 1000 tiles at random positions with random velocities
        for (i in 0...TILE_COUNT) {
            var x = Math.random() * (screenWidth - TILE_SIZE);
            var y = Math.random() * (screenHeight - TILE_SIZE);
            var tile = new Tile(tileBatch, regionId);
            tile.x = x;
            tile.y = y;
            tile.width = TILE_SIZE;
            tile.height = TILE_SIZE;
            tile.visible = true;
            tileData.push(tile);

            // Random velocity
            var speed = MIN_SPEED + Math.random() * (MAX_SPEED - MIN_SPEED);
            var angle = Math.random() * Math.PI * 2;
            var vx = Math.cos(angle) * speed;
            var vy = Math.sin(angle) * speed;
            tileVelocities.push({vx: vx, vy: vy});
        }
        
        trace("TileBatchPerformanceTest: Created " + TILE_COUNT + " moving tiles");
        trace("TileBatchPerformanceTest: Press ESC to exit");
        
        // Setup font for FPS display
        setupFont(renderer);
    }
    
    /**
     * Setup bitmap font for FPS display
     */
    private function setupFont(renderer:Renderer):Void {
        // Load font data
        var fontData = FontLoader.load(app.resources.getText("fonts/nokia.json"));
        if (fontData == null) {
            trace("TileBatchPerformanceTest: Failed to load font");
            return;
        }
        
        // Load font texture
        var fontTextureData = app.resources.getTexture("textures/nokia.tga");
        if (fontTextureData == null) {
            trace("TileBatchPerformanceTest: Failed to load font texture");
            return;
        }
        var fontTexture = renderer.uploadTexture(fontTextureData);
        
        // Create mono shader for text
        var monoVertShader = app.resources.getText("shaders/mono.vert");
        var monoFragShader = app.resources.getText("shaders/mono.frag");
        var monoProgramInfo = renderer.createProgramInfo("mono", monoVertShader, monoFragShader);
        
        // Create bitmap font
        bitmapFont = new BitmapFont(monoProgramInfo, fontTexture, fontData);
        bitmapFont.init(renderer);
        
        // Add font to scene
        var fontEntity = new Entity("fps_text");
        var fontDisplay = new DisplayObjectComp(bitmapFont);
        fontEntity.addComponent(fontDisplay);
        addEntity(fontEntity);
        
        // Create FPS text instance
        fpsText = new Text(bitmapFont, "FPS: 60 | Tiles: " + TILE_COUNT, 10, app.window.size.y - 20);
    }
    
    override public function update(dt:Float):Void {
        super.update(dt);
        
        var size = app.window.size;

        // Update FPS counter
        fpsUpdateTimer += dt;
        if (fpsUpdateTimer >= FPS_UPDATE_INTERVAL) {
            currentFps = Math.round(1.0 / dt);
            if (fpsText != null) {
                fpsText.setText("FPS: " + currentFps + " | Tiles: " + TILE_COUNT);
            }
            fpsUpdateTimer = 0.0;
        }
        
        // Update all tile positions
        for (i in 0...tileData.length) {
            var tile = tileData[i];
            var vel = tileVelocities[i];

            // Update position
            tile.x += vel.vx * dt;
            tile.y += vel.vy * dt;

            // Bounce off edges
            if (tile.x <= 0) {
                tile.x = 0;
                vel.vx = Math.abs(vel.vx);
            } else if (tile.x + TILE_SIZE >= size.x) {
                tile.x = size.x - TILE_SIZE;
                vel.vx = -Math.abs(vel.vx);
            }

            if (tile.y <= 0) {
                tile.y = 0;
                vel.vy = Math.abs(vel.vy);
            } else if (tile.y + TILE_SIZE >= size.y) {
                tile.y = size.y - TILE_SIZE;
                vel.vy = -Math.abs(vel.vy);
            }

            tileBatch.buildTile(tile);
        }
        
        // Set tile data for rendering
        //tileBatch.setTileData(tileData);
        
        // Exit on ESC
        if (app.input.keyboard.released(27)) { // ESC key
            trace("TileBatchPerformanceTest: Exiting");
            //app.setState(new states.UITestState(app));
        }
    }
    
    override public function render(renderer:Renderer):Void {
        super.render(renderer);
    }
    
    override public function release():Void {
        trace("TileBatchPerformanceTest: Releasing resources");
        super.release();
    }
}
