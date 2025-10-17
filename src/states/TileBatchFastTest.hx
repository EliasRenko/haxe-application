package states;

import comps.DisplayObjectComp;
import comps.TileCompFast;
import comps.VelocityComp;
import State;
import App;
import Entity;
import Renderer;
import display.TileBatchFast;

/**
 * TileBatchFastTest - Test state for TileBatchFast with mouse collision detection
 * 
 * Features:
 * - 8 tiles in horizontal sequence starting at (0, 0)
 * - Mouse click collision detection
 * - Uses dev_tiles.tga texture atlas
 * - Demonstrates TileBatchFast dynamic tile management
 */
class TileBatchFastTest extends State {
    
    private var tileBatch:TileBatchFast;
    private var tileEntities:Array<Entity> = [];
    private var tileIds:Array<Int> = []; // Track tile IDs for updates
    
    public function new(app:App) {
         super("TileBatchFastTest", app);
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
        var programInfo = renderer.createProgramInfo("TileBatchFast", vertShader, fragShader);
        
        // Load the dev_tiles.tga texture
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("TileBatchFastTest: Error - Could not load dev_tiles.tga texture!");
            return;
        }
        
        // Upload texture to GPU
        var texture = renderer.uploadTexture(textureData);
        trace("TileBatchFastTest: Uploaded texture: " + texture.width + "x" + texture.height);
        
        // Create TileBatchFast for high-performance rendering
        tileBatch = new TileBatchFast(programInfo, texture);
        
        // Position the tile batch at origin
        tileBatch.x = 0;
        tileBatch.y = 0;
        tileBatch.z = 0.0;
        
        // Define regions for the 6 tiles in dev_tiles.tga (128x128 texture with 32x32 tiles)
        // We'll use these regions for our 8 tiles (cycling through the available regions)
        var regionIds = [];
        var positions = [
            {x: 0, y: 0},      // Region 0: Top-left tile
            {x: 32, y: 0},     // Region 1: Top tile
            {x: 64, y: 0},     // Region 2: Top-right tile
            {x: 0, y: 32},     // Region 3: Middle-left tile
            {x: 32, y: 32},    // Region 4: Middle tile
            {x: 64, y: 32}     // Region 5: Middle-right tile
        ];
        
        for (i in 0...6) {
            var pos = positions[i];
            var regionId = tileBatch.defineRegion(pos.x, pos.y, 32, 32);
            regionIds.push(regionId);
            trace("TileBatchFastTest: Defined region " + regionId + " at atlas (" + pos.x + "," + pos.y + ")");
        }
        
        // Create the batch entity (handles rendering for all tiles)
        var tileBatchEntity = new Entity("tilebatch_fast");
        var tileBatchDisplay = new DisplayObjectComp(tileBatch);
        tileBatchEntity.addComponent(tileBatchDisplay);
        addEntity(tileBatchEntity);
        trace("TileBatchFastTest: Created TileBatchFast entity with DisplayObjectComponent");
        
        // Create 8 tiles in horizontal sequence starting at (0, 0)
        var tileSize = 32;
        var spacing = 8; // Gap between tiles
        
        for (i in 0...8) {
            // Position tiles horizontally in sequence
            var tileX = i * (tileSize + spacing);
            var tileY = 0;
            
            // Cycle through available regions
            var regionIndex = i % regionIds.length;
            var regionId = regionIds[regionIndex];
            
            // Add tile to the batch
            var tileId = tileBatch.addTile(tileX, tileY, tileSize, tileSize, regionId);
            tileIds.push(tileId);
            
            // Create entity for this tile
            var tileEntity = new Entity("tile_fast_" + i);
            
            // Add TileCompFast to manage the tile in the batch
            var tileComp = new TileCompFast(tileBatch, tileId, tileX, tileY, tileSize, tileSize);
            tileEntity.addComponent(tileComp);
            
            // Add collision hitbox for mouse detection
            tileEntity.hitbox = {
                x: tileX + tileBatch.x,
                y: tileY + tileBatch.y,
                width: tileSize,
                height: tileSize
            };
            
            // Add to state
            addEntity(tileEntity);
            tileEntities.push(tileEntity);
            
            trace("TileBatchFastTest: Created tile " + i + " (ID: " + tileId + ") at (" + tileX + "," + tileY + ") using region " + regionId);
        }
        
        trace("TileBatchFastTest: Initialized with " + tileEntities.length + " tiles");
        trace("TileBatchFastTest: Tiles span from x=0 to x=" + (7 * (tileSize + spacing)) + " at y=0");
        trace("TileBatchFastTest: Click on tiles to test collision detection");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Left click - Add new tile at mouse position
        if (app.input.mouse.released(1)) {
            var mouseX = app.input.mouse.x;
            var mouseY = app.input.mouse.y;
            var tileSize = 32;
            var regionId = 1; // Use first region
            
            // Add tile to batch
            var tileId = tileBatch.addTile(mouseX, mouseY, tileSize, tileSize, regionId);
            
            // Create entity for the new tile
            var tileEntity = new Entity("tile_dynamic_" + tileId);
            
            // Add TileCompFast component
            var tileComp = new TileCompFast(tileBatch, tileId, mouseX, mouseY, tileSize, tileSize);
            tileEntity.addComponent(tileComp);
            
            // Add collision hitbox
            tileEntity.hitbox = {
                x: mouseX + tileBatch.x,
                y: mouseY + tileBatch.y,
                width: tileSize,
                height: tileSize
            };
            
            // Add to state and tracking array
            addEntity(tileEntity);
            tileEntities.push(tileEntity);
            
            trace("TileBatchFastTest: Added dynamic tile at (" + mouseX + "," + mouseY + ") with ID " + tileId);
        }

        // Check for mouse clicks
        if (app.input.mouse.released(2)) {
            checkTileCollisions(2);
        }

        if (app.input.mouse.released(3)) {
            checkTileCollisions(3);
        }
        
        // Optional: Display performance stats periodically
        // if (frameCount % 60 == 0) {
        //     var stats = tileBatch.getPerformanceStats();
        //     trace("TileBatchFastTest: Performance - " + stats.totalTiles + " tiles, " + 
        //           stats.vertexCount + " vertices, " + stats.indexCount + " indices");
        // }

        frameCount++;
    }
    
    /**
     * Check for mouse collision with tiles
     */
    private function checkTileCollisions(mouse:Int):Void {
        var mouseX = app.input.mouse.x;
        var mouseY = app.input.mouse.y;
        
        //trace("TileBatchFastTest: Mouse clicked at (" + mouseX + "," + mouseY + ")");
        
        var hitCount = 0;
        
        // Iterate backwards to avoid index shifting issues when removing tiles
        var i = tileEntities.length - 1;
        while (i >= 0) {
            var tileEntity = tileEntities[i];
            var tileComp = tileEntity.getComponent(TileCompFast);
            
            if (tileComp != null) {
                // Get tile position (relative to batch)
                var tileX = tileComp.x + tileBatch.x;
                var tileY = tileComp.y + tileBatch.y;
                
                // AABB collision detection
                if (mouseX >= tileX && mouseX <= tileX + tileComp.width &&
                    mouseY >= tileY && mouseY <= tileY + tileComp.height) {
                    
                    // trace("TileBatchFastTest: HIT! Clicked on tile " + i + " (" + tileEntity.id + ")");
                    // trace("  Tile bounds: (" + tileX + "," + tileY + ") to (" + 
                    //       (tileX + tileComp.width) + "," + (tileY + tileComp.height) + ")");
                    // trace("  Tile ID in batch: " + tileComp.tileId);
                    
                    // Demonstrate dynamic tile update - change the tile's region to create visual feedback

                    if (mouse == 2) {
                        changeColorOnClick(tileComp, i);
                    }

                    if (mouse == 3) {
                        // Remove tile from batch using the tile ID from the component
                        trace("TileBatchFastTest: Removing tile " + i + " (batch ID: " + tileComp.tileId + ")");
                        tileBatch.removeTile(tileComp.tileId);
                        
                        // Also remove the entity from the state
                        tileEntities.splice(i, 1);
                    }

                    hitCount++;
                }
            }
            
            i--;
        }
    }
    
    /**
     * Change tile appearance when clicked (visual feedback)
     */
    private function changeColorOnClick(tileComp:TileCompFast, tileIndex:Int):Void {
        // Cycle to next region to show visual feedback
        var currentRegion = tileBatch.getTile(tileComp.tileId).regionId;
        
        trace("TileBatchFastTest: BEFORE update - tile " + tileIndex + " has region " + currentRegion);
        
        // Cycle through regions 1-6 (regions are auto-incremented starting from 1)
        var nextRegion = currentRegion + 1;
        if (nextRegion > tileBatch.getRegionCount()) {
            nextRegion = 1; // Wrap back to first region
        }
        
        trace("TileBatchFastTest: Changing tile " + tileIndex + " from region " + currentRegion + " to " + nextRegion);
        trace("  Total regions available: " + tileBatch.getRegionCount());
        
        // Update the tile's region (demonstrates TileBatchFast dynamic updates)
        tileComp.setRegion(nextRegion);
        
        // Verify the change took effect
        var actualRegion = tileBatch.getTile(tileComp.tileId).regionId;
        trace("TileBatchFastTest: AFTER update - tile " + tileIndex + " now has region " + actualRegion);
        
        if (actualRegion != nextRegion) {
            trace("TileBatchFastTest: ERROR - Region update failed! Expected " + nextRegion + " but got " + actualRegion);
        }
    }
    
    private var frameCount:Int = 0;
    
    // override public function lateUpdate():Void {
    //     super.lateUpdate();
    //     frameCount++;
    // }
}
