package states;

import State;
import Entity;
import App;
import Renderer;
import ProgramInfo;
import Texture;
import display.TileBatch;
import math.Matrix;
import differ.Collision;
import differ.shapes.Circle;
import differ.shapes.Polygon;
import differ.shapes.Shape;
import differ.data.ShapeCollision;
import comps.DisplayObjectComp;

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
    private var tileBatch:TileBatch;
    private var texture:Texture;
    private var programInfo:ProgramInfo;
    
    // Player entity
    private var player:PlayerEntity;
    
    // Collision tiles (walls)
    private var collisionTiles:Array<CollisionTile> = [];
    
    // Constants
    private static inline var TILE_SIZE:Int = 32;
    private static inline var PLAYER_SPEED:Float = 200.0;
    private static inline var PLAYER_RADIUS:Float = 16.0;
    
    public function new(app:App) {
        super("CollisionTestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("CollisionTestState: Initializing");
        
        // Setup camera for 2D
        camera.ortho = true;
        
        // Get renderer
        var renderer = app.getRenderer();
        
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
        tileBatch = new TileBatch(programInfo, texture);
        
        // Define atlas region (using first 32x32 tile)
        var regionId = tileBatch.defineRegion(0, 0, 32, 32);
        
        // Create test level layout
        createTestLevel(regionId);
        
        // Create TileBatch entity for rendering
        var tileBatchEntity = new Entity("level_tiles");
        var tileBatchDisplay = new DisplayObjectComp(tileBatch);
        tileBatchEntity.addComponent(tileBatchDisplay);
        addEntity(tileBatchEntity);
        
        // Create player
        player = new PlayerEntity(this, programInfo, renderer);
        player.x = 400;
        player.y = 300;
        addEntity(player);
        
        trace("CollisionTestState: Setup complete");
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
        tileBatch.updateBuffers(app.getRenderer());
        
        trace('CollisionTestState: Created ${collisionTiles.length} collision tiles');
    }
    
    override public function update(deltaTime:Float):Void {
        // Update player FIRST (before other entities)
        if (player != null && player.active) {
            player.update(deltaTime);
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
    
    private var tileBatch:TileBatch;
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
            
            tileBatch = new TileBatch(programInfo, texture);
            
            // Define atlas region (use second tile at x=32)
            var regionId = tileBatch.defineRegion(32, 0, 32, 32);
            
            // Add player tile to batch
            tileId = tileBatch.addTile(0, 0, PLAYER_SIZE, PLAYER_SIZE, regionId);
            tileBatch.updateBuffers(renderer);
            
            // Add DisplayObjectComp for rendering
            var displayComp = new DisplayObjectComp(tileBatch);
            addComponent(displayComp);
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
            tileBatch.updateBuffers(state.app.getRenderer());
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
