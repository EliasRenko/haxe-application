package states;

import State;
import Entity;
import App;
import Renderer;
import ProgramInfo;
import Texture;
import display.ManagedTileBatch;
import display.BitmapFont;
import display.Text;
import loaders.FontLoader;
import differ.Collision;
import differ.shapes.Circle;
import differ.shapes.Polygon;
import differ.shapes.Shape;
import differ.data.ShapeCollision;
import entity.DisplayEntity;


/**
 * Test state demonstrating collision detection and response
 * Uses differ for collision detection with TileBatch rendering
 * 
 * Features:
 * - Tile-based level with walls
 * - Player movement with gravity and jumping
 * - Collision detection and resolution
 * - Wall sliding
 * 
 * Controls:
 * - A/D or Arrow Keys: Move left/right
 * - Space/W: Jump (only when on ground)
 */
class CollisionTestState extends State {
    
    // Rendering
    private var tileBatch:ManagedTileBatch;
    private var texture:Texture;
    private var programInfo:ProgramInfo;
    
    // Text display
    private var bitmapFont:BitmapFont;
    private var velocityXText:Text;
    private var velocityYText:Text;
    
    // Player entity
    private var player:PlayerEntity;
    
    // Collision tiles (walls)
    private var collisionTiles:Array<CollisionTile> = [];
    
    // Constants
    private static inline var TILE_SIZE:Int = 32;
    private static inline var PLAYER_SPEED:Float = 200.0;
    private static inline var PLAYER_RADIUS:Float = 16.0;
    
        private var lineBatch:display.LineBatch;
        private var shapeDrawer:differ.ShapeDrawer;
    public function new(app:App) {
        super("CollisionTestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("CollisionTestState: Initializing");
        
        // Setup camera for 2D
        camera.ortho = true;
        
        // Get renderer
        var renderer = app.renderer;
        
        // Get or create shader program
        var vertShader = app.resources.getText("shaders/textured.vert");
        var fragShader = app.resources.getText("shaders/textured.frag");
        programInfo = renderer.createProgramInfo("textured", vertShader, fragShader);
        
        // Load texture for tiles
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("CollisionTestState: Failed to load texture");
            return;
        }
        
        // Upload texture to GPU
        texture = renderer.uploadTexture(textureData);
        
        // Create TileBatch for rendering tiles
        tileBatch = new ManagedTileBatch(programInfo, texture);
        tileBatch.init(renderer);
        
        // Define atlas region (using first 32x32 tile)
        var regionId = tileBatch.defineRegion(0, 0, 32, 32);
        
        // Create test level layout
        createTestLevel(regionId);
        
        // Create TileBatch entity for rendering
        var tileBatchEntity = new DisplayEntity(tileBatch, "level_tiles");
        addEntity(tileBatchEntity);
        
        // Create player
        player = new PlayerEntity(this, programInfo, renderer);
        player.x = 400;
        player.y = 300;
        addEntity(player);
        
        // Setup text display for velocity
        setupTextDisplay(renderer);
        
        // Setup debug line batch and shape drawer
        var lineVertShader = app.resources.getText("shaders/line.vert");
        var lineFragShader = app.resources.getText("shaders/line.frag");
        var lineProgram = renderer.createProgramInfo("line", lineVertShader, lineFragShader);
        lineBatch = new display.LineBatch(lineProgram, false); // not persistent
        shapeDrawer = new differ.ShapeDrawer(lineBatch);
        var lineEntity = new entity.DisplayEntity(lineBatch, "debug_lines");
        addEntity(lineEntity);

        trace("CollisionTestState: Setup complete");
    }
    
    /**
     * Setup text display for velocity information
     */
    private function setupTextDisplay(renderer:Renderer):Void {
        // Load font
        var fontData = FontLoader.load(app.resources.getText("fonts/nokia.json"));
        if (fontData == null) {
            trace("CollisionTestState: Failed to load font");
            return;
        }
        
        // Load font texture
        var fontTextureData = app.resources.getTexture("textures/nokia.tga");
        if (fontTextureData == null) {
            trace("CollisionTestState: Failed to load font texture");
            return;
        }
        
        var fontTexture = renderer.uploadTexture(fontTextureData);
        
        // Create shader program for text (mono shader for 1bpp fonts)
        var monoVertShader = app.resources.getText("shaders/mono.vert");
        var monoFragShader = app.resources.getText("shaders/mono.frag");
        var monoProgramInfo = renderer.createProgramInfo("mono", monoVertShader, monoFragShader);
        
        // Create BitmapFont (shared)
        bitmapFont = new BitmapFont(monoProgramInfo, fontTexture, fontData);
        
        // Initialize the font's buffers
        bitmapFont.init(renderer);
        
        // Add font to scene for rendering
        var fontEntity = new DisplayEntity(bitmapFont, "bitmap_font");
        addEntity(fontEntity);
        
        // Create text instances
        velocityXText = new Text(bitmapFont, "Velocity X: 0.0");
        velocityXText.x = 10;
        velocityXText.y = 10;
        
        velocityYText = new Text(bitmapFont, "Velocity Y: 0.0");
        velocityYText.x = 10;
        velocityYText.y = 30;
        
        // Force buffer update after adding text tiles
        bitmapFont.needsBufferUpdate = true;
        bitmapFont.updateBuffers(renderer);
        
        trace("CollisionTestState: BitmapFont has " + bitmapFont.getTileCount() + " tiles");
        trace("CollisionTestState: BitmapFont vertices: " + bitmapFont.vertices.length + ", indices: " + bitmapFont.indices.length);
        
        trace("CollisionTestState: Text display setup complete");
    }
    
    /**
     * Create a simple test level with walls
     */
    private function createTestLevel(regionId:Int):Void {
        // Level layout (1 = wall, 0 = empty)
        var levelData:Array<Array<Int>> = [
            [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1],
            [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        ];
        
        // Create collision tiles and add to TileBatch
        for (row in 0...levelData.length) {
            for (col in 0...levelData[row].length) {
                if (levelData[row][col] == 1) {
                    var x = col * TILE_SIZE;
                    var y = row * TILE_SIZE;
                    
                    // Add tile to TileBatch for rendering
                    var tileId = tileBatch.addTile(x, y, TILE_SIZE, TILE_SIZE, regionId);
                    
                    // Create collision shape (rectangle polygon)
                    var collisionShape = Polygon.rectangle(
                        x + TILE_SIZE / 2,  // center x
                        y + TILE_SIZE / 2,  // center y
                        TILE_SIZE,          // width
                        TILE_SIZE           // height
                    );
                    
                    // Store collision tile
                    collisionTiles.push({
                        tileId: tileId,
                        shape: collisionShape,
                        x: x,
                        y: y
                    });
                }
            }
        }
        
        // Update TileBatch buffers
        tileBatch.updateBuffers(app.renderer);
        
        trace('CollisionTestState: Created ${collisionTiles.length} collision tiles');
    }
    
    var someFloatValue:Float = 0.0;

    override public function update(deltaTime:Float):Void {

        // Update player FIRST (before other entities)
        if (player != null && player.active) {
            player.update(deltaTime);
            
            // Update velocity text displays
            if (velocityXText != null) {
                velocityXText.setText("Velocity X: " + Math.round(player.velocityX * 10) / 10);
            }
            if (velocityYText != null) {
                velocityYText.setText("Velocity Y: " + Math.round(player.velocityY * 10) / 10);
            }
        }
        
        // Check collisions AFTER player movement
        if (player != null && player.collisionShape != null) {
            checkCollisions();
        }
        
        // Update other entities (skip player since we already updated it)
        for (entity in entities) {
            if (entity != null && entity != player && entity.active) {
                entity.update(deltaTime);
            }
        }
        
        // Late update all entities
        for (entity in entities) {
            if (entity != null && entity.active) {
                entity.lateUpdate(deltaTime);
            }
        }

        // Debug draw: player and collision shapes
        if (shapeDrawer != null && player != null && player.collisionShape != null) {
            shapeDrawer.drawShape(player.collisionShape);
        }
        if (shapeDrawer != null) {
            for (tile in collisionTiles) {
                shapeDrawer.drawShape(tile.shape);
            }
        }
        
    }

    override public function render(renderer:Renderer):Void {

        // // Debug: Check if lineBatch DisplayEntity is active and visible
        // for (entity in entities) {
        //     if (Std.is(entity, entity.DisplayEntity)) {
        //         var de = cast(entity, entity.DisplayEntity);
        //         if (de.displayObject == lineBatch) {
        //             trace('LineBatch DisplayEntity: active=' + de.active + ', visible=' + de.visible);
        //         }
        //     }
        // }

        // // Debug: Check if lines are batched
        // if (lineBatch != null) {
        //     trace('LineBatch: lineCount=' + lineBatch.lineCount + ', vertices=' + lineBatch.vertices.length);
        // }

        super.render(renderer);

        if (lineBatch != null && !lineBatch.isPersistent()) {
            lineBatch.clear();
        }
        
        //lineBatch.render(camera.getMatrix());
        //renderer.renderDisplayObject(lineBatch, camera.getMatrix());
    }
    
    /**
     * Check and resolve collisions between player and tiles
     */
    private function checkCollisions():Void {
        for (tile in collisionTiles) {
            var collision = Collision.shapeWithShape(player.collisionShape, tile.shape);
            
            if (collision != null) {
                // Collision detected! Resolve by pushing player out
                player.x += collision.separationX;
                player.y += collision.separationY;
                
                // Update player collision shape position
                player.updateCollisionShape();
                
                // Check if collision is from below (standing on ground)
                // If the separation is mostly vertical (pointing up), player is grounded
                var ny = collision.unitVectorY;
                if (ny < -0.7) { // Pointing upward (ground collision)
                    player.isGrounded = true;
                    player.velocityY = 0; // Stop falling
                }
                
                // Stop player velocity in collision direction
                var nx = collision.unitVectorX;
                var dot = player.velocityX * nx + player.velocityY * ny;
                
                if (dot < 0) {
                    player.velocityX -= dot * nx;
                    player.velocityY -= dot * ny;
                }
            }
        }
    }
}

/**
 * Player entity with movement and collision
 */
class PlayerEntity extends Entity {
    
    public var velocityX:Float = 0;
    public var velocityY:Float = 0;
    public var x:Float = 0;
    public var y:Float = 0;
    public var collisionShape:Circle;
    
    private var tileBatch:ManagedTileBatch;
    private var texture:Texture;
    private var tileId:Int = -1;
    private var keyboard:input.Keyboard;
    
    // Jump/gravity mechanics
    public var isGrounded:Bool = false;
    private var wasGrounded:Bool = false;
    
    private static inline var PLAYER_SPEED:Float = 150.0; // Pixels per second
    private static inline var PLAYER_RADIUS:Float = 16.0;
    private static inline var PLAYER_SIZE:Int = 32;
    private static inline var GRAVITY:Float = 800.0; // Pixels per second squared
    private static inline var JUMP_VELOCITY:Float = -350.0; // Negative = up (pixels per second)
    private static inline var MAX_FALL_SPEED:Float = 400.0; // Maximum downward velocity
    
    public function new(state:State, programInfo:ProgramInfo, renderer:Renderer) {
        super("player");
        this.state = state;
        
        // Get keyboard for input
        keyboard = state.app.input.keyboard;
        
        // Load texture for player (use a different tile)
        var textureData = state.app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData != null) {
            texture = renderer.uploadTexture(textureData);
            
            tileBatch = new ManagedTileBatch(programInfo, texture);
            
            // Define atlas region (use second tile at x=32)
            var regionId = tileBatch.defineRegion(32, 0, 32, 32);
            
            // Add player tile to batch
            tileId = tileBatch.addTile(0, 0, PLAYER_SIZE, PLAYER_SIZE, regionId);
            tileBatch.updateBuffers(renderer);
            
            // Add DisplayEntity for rendering
            // (Handled by state if needed, or refactor PlayerEntity to DisplayEntity if always renderable)
        }
        
        // Create collision shape (circle)
        collisionShape = new Circle(0, 0, PLAYER_RADIUS);
    }
    
    public function updateCollisionShape():Void {
        // Update collision shape position to match entity
        collisionShape.x = x;
        collisionShape.y = y;
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Store previous grounded state
        wasGrounded = isGrounded;
        isGrounded = false;
        
        // Apply gravity
        velocityY += GRAVITY * deltaTime;
        
        // Clamp fall speed
        if (velocityY > MAX_FALL_SPEED) {
            velocityY = MAX_FALL_SPEED;
        }
        
        // Get horizontal input
        velocityX = 0;
        
        if (keyboard.check(Keycode.A)) {
            velocityX = -PLAYER_SPEED;
        }
        if (keyboard.check(Keycode.D)) {
            velocityX = PLAYER_SPEED;
        }
        
        // Jump input (Space or W) - only when grounded
        var wantToJump = keyboard.pressed(Keycode.SPACE) || keyboard.pressed(Keycode.W);
        if (wantToJump && wasGrounded) {
            velocityY = JUMP_VELOCITY;
            trace("Player jumped! wasGrounded=" + wasGrounded + " isGrounded=" + isGrounded);
        }
        
        // Update position
        x += velocityX * deltaTime;
        y += velocityY * deltaTime;
        
        // Update collision shape
        updateCollisionShape();
        
        // Update tile position in batch
        if (tileBatch != null && tileId != -1) {
            tileBatch.updateTilePosition(tileId, x - PLAYER_SIZE / 2, y - PLAYER_SIZE / 2);
            tileBatch.updateBuffers(state.app.renderer);
        }
    }
}

/**
 * Collision tile data structure
 */
typedef CollisionTile = {
    var tileId:Int;
    var shape:Shape;
    var x:Float;
    var y:Float;
}
