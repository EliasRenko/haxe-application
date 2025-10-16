package states;

import comps.DisplayObjectComp;
import comps.TileComp;
import comps.VelocityComp;
import State;
import App;
import Entity;
import Renderer;
import display.TileBatch;

class CollisionTest extends State {
    
    private var tileBatch:TileBatch;
    private var tileEntities:Array<Entity> = [];
    
    public function new(app:App) {
         super("CollisionTest", app);
    }
    
    override public function init():Void {
        super.init();
        
        // Setup camera for 2D orthographic view
        camera.ortho = true;
        
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Create ProgramInfo for textured rendering
        var vertShader = app.resources.getText("shaders/textured.vert");
        var fragShader = app.resources.getText("shaders/textured.frag");
        var programInfo = renderer.createProgramInfo("Image", vertShader, fragShader);
        
        // Load the dev_tiles.tga texture
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("Error: Could not load dev_tiles.tga texture!");
            return;
        }
        
        // Upload texture to GPU
        var texture = renderer.uploadTexture(textureData);
        trace("Uploaded texture: " + texture.width + "x" + texture.height);
        
        // Create TileBatch for rendering tiles
        tileBatch = new TileBatch(programInfo, texture);
        
        // Position the tile batch
        tileBatch.x = 0;
        tileBatch.y = 0;
        tileBatch.z = 0.0;
        
        // Define regions for the 6 tiles in dev_tiles.tga (128x128 texture with 32x32 tiles)
        var regionIds = [];
        var positions = [
            {x: 0, y: 0},      // Top-left tile
            {x: 32, y: 0},     // Top tile
            {x: 64, y: 0},     // Top-right tile
            {x: 0, y: 32},     // Middle-left tile
            {x: 32, y: 32},    // Middle tile
            {x: 64, y: 32}     // Middle-right tile
        ];
        
        for (i in 0...6) {
            var pos = positions[i];
            var regionId = tileBatch.defineRegion(pos.x, pos.y, 32, 32);
            regionIds.push(regionId);
            trace("Defined region " + regionId + " at atlas (" + pos.x + "," + pos.y + ")");
        }
        
        // Create the batch entity (handles rendering for all tiles)
        var tileBatchEntity = new Entity("tilebatch");
        var tileBatchDisplay = new DisplayObjectComp(tileBatch);
        tileBatchEntity.addComponent(tileBatchDisplay);
        addEntity(tileBatchEntity);
        trace("Created TileBatch entity with DisplayObjectComponent");
        
        // Create 6 individual tile entities
        var tileSize = 32;
        var spacing = 8;
        
        for (i in 0...6) {
            var row = Std.int(i / 3);
            var col = i % 3;
            
            var tileX = col * (tileSize + spacing);
            var tileY = row * (tileSize + spacing);
            var regionIndex = i % regionIds.length;
            
            // Add tile to the batch
            var tileId = tileBatch.addTile(tileX, tileY, tileSize, tileSize, regionIds[regionIndex]);
            
            // Create entity for this tile
            var tileEntity = new Entity("tile_" + i);
            
            // Add TileComponent to manage the tile in the batch
            var tileComp = new TileComp(tileBatch, tileId, tileX, tileY, tileSize, tileSize);
            tileEntity.addComponent(tileComp);
            
            // Add collision hitbox
            tileEntity.hitbox = {
                x: tileX + tileBatch.x,
                y: tileY + tileBatch.y,
                width: tileSize,
                height: tileSize
            };
            
            // Add some random velocity for demonstration
            //var velocityX = Math.random() * 40 - 20; // Random between -20 and 20
            //var velocityY = Math.random() * 40 - 20;
            //var velocity = new VelocityComp(velocityX, velocityY);
            //tileEntity.addComponent(velocity);
            
            // Add to state
            addEntity(tileEntity);
            tileEntities.push(tileEntity);
            
            //trace("Created tile entity '" + tileEntity.id + "' at (" + tileX + "," + tileY + ") with velocity (" + velocityX + "," + velocityY + ")");
        }
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        if (app.input.mouse.isButtonPressed(1)) {
            // Handle mouse click
            var mouseX = app.input.mouse.x;
            var mouseY = app.input.mouse.y;

            for (tileEntity in tileEntities) {
                var tileComp = tileEntity.getComponent(TileComp);
                if (tileComp != null) {
                    // Get tile position (relative to batch)
                    var tileX = tileComp.x + tileBatch.x;
                    var tileY = tileComp.y + tileBatch.y;
                    
                    if (mouseX >= tileX && mouseX <= tileX + tileComp.width &&
                        mouseY >= tileY && mouseY <= tileY + tileComp.height) {
                        trace("Clicked on tile entity: " + tileEntity.id);
                    }
                }
            }
        }

        // Update tile positions in the batch based on their components
        // for (tileEntity in tileEntities) {
        //     var tileComp = tileEntity.getComponent(TileComp);
        //     var velocityComp = tileEntity.getComponent(VelocityComp);
            
        //     if (tileComp != null && velocityComp != null) {
        //         // Calculate new position
        //         var newX = tileComp.x + velocityComp.velocityX * deltaTime;
        //         var newY = tileComp.y + velocityComp.velocityY * deltaTime;
                
        //         // Simple screen wrapping (assuming 640x480 screen)
        //         var screenWidth = 640 - 200; // Account for batch offset
        //         var screenHeight = 480 - 200;
                
        //         if (newX < 0) {
        //             newX = screenWidth;
        //         } else if (newX > screenWidth) {
        //             newX = 0;
        //         }
                
        //         if (newY < 0) {
        //             newY = screenHeight;
        //         } else if (newY > screenHeight) {
        //             newY = 0;
        //         }
                
        //         // Update tile position
        //         tileComp.setPosition(newX, newY);
                
        //         // Update hitbox
        //         if (tileEntity.hitbox != null) {
        //             tileEntity.hitbox.x = newX + tileBatch.x;
        //             tileEntity.hitbox.y = newY + tileBatch.y;
        //         }
        //     }
        // }
        
        // Simple collision detection between tiles
        checkTileCollisions();
    }
    
    private function checkTileCollisions():Void {
        for (i in 0...tileEntities.length) {
            var entityA = tileEntities[i];
            if (entityA.hitbox == null) continue;
            
            for (j in (i + 1)...tileEntities.length) {
                var entityB = tileEntities[j];
                if (entityB.hitbox == null) continue;
                
                // AABB collision detection
                if (checkAABBCollision(entityA.hitbox, entityB.hitbox)) {
                    // Collision detected! Bounce them off each other
                    var velocityA = entityA.getComponent(VelocityComp);
                    var velocityB = entityB.getComponent(VelocityComp);
                    
                    if (velocityA != null && velocityB != null) {
                        // Simple bounce: swap velocities
                        var tempVX = velocityA.velocityX;
                        var tempVY = velocityA.velocityY;
                        
                        velocityA.velocityX = velocityB.velocityX;
                        velocityA.velocityY = velocityB.velocityY;
                        velocityB.velocityX = tempVX;
                        velocityB.velocityY = tempVY;
                        
                        trace("Collision between " + entityA.id + " and " + entityB.id);
                    }
                }
            }
        }
    }
    
    private function checkAABBCollision(a:utils.Rect, b:utils.Rect):Bool {
        return a.x < b.x + b.width &&
               a.x + a.width > b.x &&
               a.y < b.y + b.height &&
               a.y + a.height > b.y;
    }
}