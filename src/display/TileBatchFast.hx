package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import Texture;
import math.Matrix;

/**
 * TileBatchFast - High-performance tile batching system with dynamic buffer updates
 * 
 * Core functionality:
 * - Batch multiple tiles using the same texture atlas
 * - Free-form positioning (no grid constraints)
 * - Add/remove/update individual tiles by ID
 * - Dynamic partial buffer updates using uploadVertexDataPartial/uploadIndexDataPartial
 * - Intelligent update strategy selection (partial vs full rebuild)
 * - Automatic vertex buffer management and optimization
 * 
 * Performance features:
 * - Partial buffer updates for small changes (≤10 tiles or ≤30% of total)
 * - Full rebuild for major changes to maintain optimal performance
 * - Efficient dirty tile tracking and batched updates
 * - Vertex mapping for O(1) tile-to-buffer lookups
 * 
 * Usage:
 * 1. Create TileBatchFast with programInfo and texture
 * 2. Define atlas regions with defineRegion()
 * 3. Add tiles with addTile() using region IDs
 * 4. Update tiles with updateTile() for dynamic changes
 * 5. Remove tiles with removeTile() when no longer needed
 */
class TileBatchFast extends DisplayObject {
    
    // Tile data structure
    public var tiles:Map<Int, TileInstanceFast> = new Map(); // tileId -> TileInstanceFast
    public var atlasTexture:Texture = null;
    public var atlasRegions:Map<Int, AtlasRegionFast> = new Map(); // regionId -> AtlasRegionFast
    
    // Buffer management for dynamic updates
    private var __nextTileId:Int = 1; // Auto-incrementing tile ID
    private var __nextRegionId:Int = 1; // Auto-incrementing region ID
    private var __bufferDirty:Bool = true;
    private var __vertexCache:Array<Float> = [];
    private var __indexCache:Array<UInt> = [];
    
    // Dynamic update tracking
    private var __dirtyTiles:Array<Int> = [];    // List of tiles that need updating
    private var __removedTiles:Array<Int> = [];  // Tiles marked for removal
    private var __tileVertexMap:Map<Int, Int> = new Map(); // tileId -> vertex start index
    private var __tileOrderMap:Map<Int, Int> = new Map(); // tileId -> order in buffer
    private var __orderedTiles:Array<Int> = []; // Tiles in buffer order
    
    // Performance constants
    private static inline var VERTICES_PER_TILE:Int = 4;  // Quad = 4 vertices
    private static inline var INDICES_PER_TILE:Int = 6;   // 2 triangles = 6 indices
    private static inline var FLOATS_PER_VERTEX:Int = 5;  // x,y,z,u,v
    private static inline var FLOATS_PER_TILE:Int = VERTICES_PER_TILE * FLOATS_PER_VERTEX; // 20 floats per tile
    
    // Performance thresholds
    private static inline var PARTIAL_UPDATE_THRESHOLD:Int = 10; // Use partial updates for <= 10 tiles
    private static inline var FULL_REBUILD_THRESHOLD:Float = 0.8; // Rebuild if >80% of tiles changed (was 0.3)
    
    // Safety mechanisms
    private var __partialUpdatesEnabled:Bool = true; // Can be disabled if artifacts detected
    private var __consecutivePartialFailures:Int = 0; // Track failures to auto-disable
    private var __isUpdating:Bool = false; // Flag to prevent rendering during buffer updates
    
    /**
     * Create a new TileBatch
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     */
    public function new(programInfo:ProgramInfo, texture:Texture) {
        this.atlasTexture = texture;
        
        // Start with empty vertices and indices
        var emptyVertices = new Vertices([]);
        var emptyIndices = new Indices([]);
        
        super(programInfo, emptyVertices, emptyIndices);
        
        // Set OpenGL properties (matching Image class)
        mode = GL.TRIANGLES;
        
        // Set proper alpha blending for transparent textures
        blendFactors = {
            source: GL.SRC_ALPHA,
            destination: GL.ONE_MINUS_SRC_ALPHA
        };
        
        // Set the texture for the display object
        setTexture(texture);
    }
    
    /**
     * Define an atlas region using pixel coordinates
     * @param atlasX Atlas X coordinate in pixels
     * @param atlasY Atlas Y coordinate in pixels
     * @param atlasWidth Atlas width in pixels
     * @param atlasHeight Atlas height in pixels
     * @return Region ID for use in addTile
     */
    public function defineRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        var regionId = __nextRegionId++;
        
        var region = new AtlasRegionFast();
        region.x = atlasX;
        region.y = atlasY;
        region.width = atlasWidth;
        region.height = atlasHeight;
        
        // Convert pixel coordinates to UV coordinates
        // No V-flipping needed since TGA loader now handles proper orientation
        region.u1 = atlasX / atlasTexture.width;
        region.v1 = atlasY / atlasTexture.height;
        region.u2 = (atlasX + atlasWidth) / atlasTexture.width;
        region.v2 = (atlasY + atlasHeight) / atlasTexture.height;
        
        trace("TileBatch: defineRegion DEBUG");
        trace("  Pixel coords: (" + atlasX + "," + atlasY + ") to (" + (atlasX + atlasWidth) + "," + (atlasY + atlasHeight) + ")");
        trace("  Texture size: " + atlasTexture.width + "x" + atlasTexture.height);
        trace("  Calculated UV: (" + region.u1 + "," + region.v1 + ") to (" + region.u2 + "," + region.v2 + ")");
        
        atlasRegions.set(regionId, region);
        
        trace("TileBatch: Defined region " + regionId + " at (" + atlasX + "," + atlasY + ") size=" + atlasWidth + "x" + atlasHeight + " UV=(" + region.u1 + "," + region.v1 + "," + region.u2 + "," + region.v2 + ")");
        return regionId;
    }
    
    /**
     * Add a tile to the batch using a predefined atlas region
     * @param x World X position
     * @param y World Y position
     * @param width Tile width in world units
     * @param height Tile height in world units
     * @param regionId Atlas region ID (from defineRegion)
     * @return Tile ID for future reference
     */
    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        if (!atlasRegions.exists(regionId)) {
            trace("TileBatch: Error - Region ID " + regionId + " does not exist!");
            return -1;
        }
        
        var tileId = __nextTileId++;
        
        var tile = new TileInstanceFast();
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.regionId = regionId;
        
        tiles.set(tileId, tile);
        
        // For dynamic updates: track this as a new tile
        if (initialized && !__bufferDirty) {
            // Add to existing buffer structure
            var orderIndex = __orderedTiles.length;
            __orderedTiles.push(tileId);
            __tileOrderMap.set(tileId, orderIndex);
            __tileVertexMap.set(tileId, orderIndex * VERTICES_PER_TILE);
            
            // Generate vertices for the new tile
            var tileVertices = generateTileVertices(tile);
            var tileIndices = generateTileIndices(orderIndex * VERTICES_PER_TILE);
            
            // Extend buffers
            for (vertex in tileVertices) {
                __vertexCache.push(vertex);
            }
            for (index in tileIndices) {
                __indexCache.push(index);
            }
            
            // Update DisplayObject data
            this.vertices = new Vertices(__vertexCache);
            this.indices = new Indices(__indexCache);
            __verticesToRender = Std.int(__vertexCache.length / FLOATS_PER_VERTEX);
            __indicesToRender = __indexCache.length;
            
            // CRITICAL: When adding tiles, we need to upload BOTH vertex and index data
            // because the index buffer size changed, not just vertex content
            // Force a full upload rather than partial update
            __bufferDirty = true;
            needsBufferUpdate = true;
            
            trace("TileBatchFast: Added tile " + tileId + " dynamically at position " + orderIndex + " - forcing full buffer update due to index changes");
        } else {
            // Full rebuild needed
            __bufferDirty = true;
            if (initialized) {
                needsBufferUpdate = true;
            }
        }
        
        var region = atlasRegions.get(regionId);
        trace("TileBatch: Added tile " + tileId + " at (" + x + "," + y + ") size=" + width + "x" + height + " using region " + regionId);
        return tileId;
    }
    
    /**
     * Remove a tile from the batch
     * @param tileId Tile ID to remove
     * @return True if tile was found and removed
     */
    public function removeTile(tileId:Int):Bool {
        if (tiles.exists(tileId)) {
            tiles.remove(tileId);
            
            // For dynamic updates: track removal
            if (initialized && !__bufferDirty && __tileOrderMap.exists(tileId)) {
                __removedTiles.push(tileId);
                needsBufferUpdate = true;
                trace("TileBatchFast: Marked tile " + tileId + " for removal");
            } else {
                // Full rebuild needed
                __bufferDirty = true;
                if (initialized) {
                    needsBufferUpdate = true;
                }
            }
            
            return true;
        }
        return false;
    }
    
    /**
     * Update an existing tile's properties
     * @param tileId Tile ID to update
     * @param x New X position (optional)
     * @param y New Y position (optional)
     * @param width New width (optional)
     * @param height New height (optional)
     * @param regionId New region ID (optional)
     * @return True if tile was found and updated
     */
    public function updateTile(tileId:Int, ?x:Float, ?y:Float, ?width:Float, ?height:Float, ?regionId:Int):Bool {
        if (!tiles.exists(tileId)) {
            return false;
        }
        
        var tile = tiles.get(tileId);
        var changed = false;
        
        if (x != null && tile.x != x) { tile.x = x; changed = true; }
        if (y != null && tile.y != y) { tile.y = y; changed = true; }
        if (width != null && tile.width != width) { tile.width = width; changed = true; }
        if (height != null && tile.height != height) { tile.height = height; changed = true; }
        if (regionId != null && tile.regionId != regionId) { 
            if (atlasRegions.exists(regionId)) {
                tile.regionId = regionId; 
                changed = true; 
            } else {
                trace("TileBatchFast: Warning - Invalid region ID " + regionId + " in updateTile");
            }
        }
        
        if (changed) {
            // TEMPORARY: Force full rebuild instead of partial updates for debugging
            __bufferDirty = true;
            
            
            if (initialized) {
                needsBufferUpdate = true;
            }
            trace("TileBatchFast: Tile " + tileId + " changed, forcing full rebuild");
            
            // // For dynamic updates: track this tile as dirty
            // if (initialized && !__bufferDirty && __tileOrderMap.exists(tileId)) {
            //     if (__dirtyTiles.indexOf(tileId) == -1) {
            //         __dirtyTiles.push(tileId);
            //     }
            //     needsBufferUpdate = true;
            //     trace("TileBatchFast: Marked tile " + tileId + " as dirty for update");
            // } else {
            //     // Full rebuild needed
            //     __bufferDirty = true;
            //     if (initialized) {
            //         needsBufferUpdate = true;
            //     }
            // }
        }
        
        return changed;
    }

    /**
     * Update a tile's position
     * @param tileId Tile ID to update
     * @param x New world X position
     * @param y New world Y position
     * @return True if tile was found and updated
     */
    public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
        if (tiles.exists(tileId)) {
            var tile = tiles.get(tileId);
            tile.x = x;
            tile.y = y;
            __bufferDirty = true;
            
            if (initialized) {
                needsBufferUpdate = true;
            }
            
            return true;
        }
        
        return false;
    }
    
    /**
     * Clear all tiles from the batch
     */
    public function clear():Void {
        tiles.clear();
        __bufferDirty = true;
        
        if (initialized) {
            needsBufferUpdate = true;
        }
    }
    
    /**
     * Generate vertex data for a single tile
     */
    private function generateTileVertices(tile:TileInstanceFast):Array<Float> {
        var vertices = [];
        
        // Get UV coordinates from the atlas region
        var region = atlasRegions.get(tile.regionId);
        if (region == null) {
            trace("TileBatch: Warning - Region ID " + tile.regionId + " not found, using default UVs");
            // Use default full texture UVs as fallback
            region = new AtlasRegionFast();
            region.u1 = 0.0;
            region.v1 = 1.0;
            region.u2 = 1.0;
            region.v2 = 0.0;
        }
        
        // IMPORTANT: Flip V coordinates to compensate for Camera Y-axis flip
        // Camera has (0,0) at top-left, but texture coordinates have (0,0) at bottom-left
        // So we swap v1 and v2 to flip the texture vertically
        var v1 = region.v2;  // Swap V coordinates
        var v2 = region.v1;  // Swap V coordinates
        
        // Debug the UV coordinates being used for rendering
        trace("TileBatch: generateTileVertices DEBUG for tile regionId=" + tile.regionId);
        trace("  Region UV stored: (" + region.u1 + "," + region.v1 + ") to (" + region.u2 + "," + region.v2 + ")");
        trace("  Final vertex UV (V-flipped): (" + region.u1 + "," + v1 + ") to (" + region.u2 + "," + v2 + ")");
        
        // Create quad vertices: top-left, top-right, bottom-right, bottom-left
        // Format: [x, y, z, u, v] per vertex
        // Use flipped V coordinates to compensate for Camera coordinate system
        
        // Top-left
        vertices.push(tile.x);
        vertices.push(tile.y + tile.height);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(v1);  // Use flipped V
        
        // Top-right
        vertices.push(tile.x + tile.width);
        vertices.push(tile.y + tile.height);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(v1);  // Use flipped V
        
        // Bottom-right
        vertices.push(tile.x + tile.width);
        vertices.push(tile.y);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(v2);  // Use flipped V
        
        // Bottom-left
        vertices.push(tile.x);
        vertices.push(tile.y);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(v2);  // Use flipped V
        
        return vertices;
    }
    
    /**
     * Generate indices for a tile at the specified vertex offset
     * @param vertexOffset Starting vertex index (should be multiple of 4)
     * @return Array of 6 indices for 2 triangles
     */
    private function generateTileIndices(vertexOffset:Int):Array<UInt> {
        return [
            vertexOffset + 0,  // Top-left
            vertexOffset + 1,  // Top-right
            vertexOffset + 2,  // Bottom-right
            
            vertexOffset + 0,  // Top-left
            vertexOffset + 2,  // Bottom-right
            vertexOffset + 3   // Bottom-left
        ];
    }

    /**
     * Generate mesh data for all tiles
     */
    private function generateMesh():Void {
        __vertexCache = [];
        __indexCache = [];
        __tileVertexMap.clear();
        __tileOrderMap.clear();
        __orderedTiles = [];
        
        var vertexIndex:UInt = 0;
        var orderIndex:Int = 0;
        
        // Generate mesh for each tile
        for (tileId in tiles.keys()) {
            var tile = tiles.get(tileId);
            
            // Track tile positioning for dynamic updates
            __orderedTiles.push(tileId);
            __tileOrderMap.set(tileId, orderIndex);
            __tileVertexMap.set(tileId, vertexIndex);
            
            trace("TileBatch: Mapping tile " + tileId + " -> vertex index " + vertexIndex + " (float offset " + (vertexIndex * FLOATS_PER_VERTEX) + ")");
            
            // Generate vertices for this tile
            var tileVertices = generateTileVertices(tile);
            trace("TileBatch: Generated " + tileVertices.length + " floats for tile " + tileId + ": " + tileVertices.slice(0, Std.int(Math.min(10, tileVertices.length))));
            for (vertex in tileVertices) {
                __vertexCache.push(vertex);
            }
            
            // Generate indices for this tile
            var tileIndices = generateTileIndices(vertexIndex);
            for (index in tileIndices) {
                __indexCache.push(index);
            }
            
            vertexIndex += VERTICES_PER_TILE;
            orderIndex++;
        }
        
        // Update DisplayObject vertex data
        this.vertices = new Vertices(__vertexCache);
        this.indices = new Indices(__indexCache);
        
        // Update render counts
        __verticesToRender = Std.int(__vertexCache.length / 5);  // 5 floats per vertex
        __indicesToRender = __indexCache.length;
        
        var tileCount = 0;
        for (key in tiles.keys()) tileCount++;
        
        trace("TileBatch: Generated mesh - " + __verticesToRender + " vertices, " + __indicesToRender + " indices for " + tileCount + " tiles");
    }
    
    /**
     * Update buffers using dynamic partial updates when possible
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!initialized || atlasTexture == null) return;
        
        // Full rebuild if buffer is marked dirty
        if (__bufferDirty) {
            trace("TileBatchFast: Full rebuild triggered");
            
            // CRITICAL: Set updating flag to prevent rendering during full rebuild
            __isUpdating = true;
            
            generateMesh();
            
            renderer.uploadVertexData(vao, vbo, this.vertices.data);
            renderer.uploadIndexData(ebo, this.indices.data);
            renderer.setupVertexAttributes(programInfo);
            
            __bufferDirty = false;
            needsBufferUpdate = false;
            __dirtyTiles = [];
            __removedTiles = [];
            
            // Clear updating flag after rebuild is complete
            __isUpdating = false;
            
            trace("TileBatchFast: Full rebuild complete - " + __verticesToRender + " vertices, " + __indicesToRender + " indices");
            return;
        }
        
        // Handle removals first (requires full rebuild for now)
        if (__removedTiles.length > 0) {
            trace("TileBatchFast: Removals detected, doing full rebuild");
            __bufferDirty = true;
            return updateBuffers(renderer); // Recursive call for full rebuild
        }
        
        // Handle dirty tile updates
        if (__dirtyTiles.length > 0) {
            var totalTiles = Lambda.count(tiles);
            var dirtyPercentage = __dirtyTiles.length / totalTiles;
            
            trace("TileBatchFast: " + __dirtyTiles.length + " dirty tiles (" + Math.round(dirtyPercentage * 100) + "% of " + totalTiles + " total)");
            
            // Use partial updates if under threshold and enabled
            if (__partialUpdatesEnabled && 
                __dirtyTiles.length <= PARTIAL_UPDATE_THRESHOLD && 
                dirtyPercentage < FULL_REBUILD_THRESHOLD) {
                
                try {
                    updateTilesPartial(renderer);
                    __consecutivePartialFailures = 0; // Reset failure counter on success
                } catch (e:Dynamic) {
                    trace("TileBatchFast: Partial update failed: " + e);
                    __consecutivePartialFailures++;
                    
                    // Disable partial updates if too many failures
                    if (__consecutivePartialFailures >= 3) {
                        trace("TileBatchFast: Disabling partial updates due to repeated failures");
                        __partialUpdatesEnabled = false;
                    }
                    
                    // Fall back to full rebuild
                    __bufferDirty = true;
                    return updateBuffers(renderer);
                }
            } else {
                trace("TileBatchFast: Too many changes or partial updates disabled, doing full rebuild");
                __bufferDirty = true;
                return updateBuffers(renderer); // Recursive call for full rebuild
            }
        }
        
        // needsBufferUpdate is set to false earlier in partial update path or in full rebuild
    }
    
    /**
     * Validate buffer integrity before partial updates
     */
    private function validateBufferIntegrity():Bool {
        // Check if vertex cache size matches expected size
        var expectedVertexCount = Lambda.count(tiles) * FLOATS_PER_TILE;
        if (__vertexCache.length != expectedVertexCount) {
            trace("TileBatchFast: Buffer integrity check failed - cache size mismatch");
            trace("  Expected: " + expectedVertexCount + " floats, Got: " + __vertexCache.length + " floats");
            return false;
        }
        
        // Check if vertex mappings are valid
        for (tileId in tiles.keys()) {
            if (!__tileVertexMap.exists(tileId)) {
                trace("TileBatchFast: Buffer integrity check failed - missing vertex mapping for tile " + tileId);
                return false;
            }
            
            var vertexOffset = __tileVertexMap.get(tileId);
            var floatOffset = vertexOffset * FLOATS_PER_VERTEX;
            if (floatOffset + FLOATS_PER_TILE > __vertexCache.length) {
                trace("TileBatchFast: Buffer integrity check failed - vertex mapping out of bounds for tile " + tileId);
                trace("  Offset: " + floatOffset + ", Required: " + FLOATS_PER_TILE + ", Cache size: " + __vertexCache.length);
                return false;
            }
        }
        
        trace("TileBatchFast: Buffer integrity check passed");
        return true;
    }

    /**
     * Update only dirty tiles using partial buffer uploads
     */
    private function updateTilesPartial(renderer:Renderer):Void {
        // trace("TileBatchFast: Performing partial update for " + __dirtyTiles.length + " tiles");
        // trace("TileBatchFast: Current buffer state - cache size: " + __vertexCache.length + ", total tiles: " + Lambda.count(tiles));
        
        // Validate buffer integrity before proceeding
        if (!validateBufferIntegrity()) {
            //trace("TileBatchFast: Buffer integrity check failed, forcing full rebuild");
            __bufferDirty = true;
            return updateBuffers(renderer);
        }
        
        // CRITICAL: Clear needsBufferUpdate BEFORE partial uploads to prevent
        // the rendering system from calling updateBuffers() and overwriting our changes
        needsBufferUpdate = false;
        
        // Debug: Print current vertex mappings
        //trace("TileBatchFast: Current vertex mappings:");
        for (tileId in tiles.keys()) {
            if (__tileVertexMap.exists(tileId)) {
                var vertexOffset = __tileVertexMap.get(tileId);
                var floatOffset = vertexOffset * FLOATS_PER_VERTEX;
                trace("  Tile " + tileId + " -> vertex offset " + vertexOffset + " (float offset " + floatOffset + ")");
            }
        }
        
        // Collect all updates first to ensure atomic operation
        var updates:Array<{offset:Int, data:Array<Float>, tileId:Int}> = [];
        
        for (tileId in __dirtyTiles) {
            if (!tiles.exists(tileId) || !__tileVertexMap.exists(tileId)) {
                trace("TileBatchFast: Warning - Dirty tile " + tileId + " not found in maps");
                continue;
            }
            
            var tile = tiles.get(tileId);
            var vertexStartIndex = __tileVertexMap.get(tileId);
            
            // Generate new vertex data for this tile
            var newVertices = generateTileVertices(tile);
            
            // Validate bounds before proceeding
            var cacheOffset = vertexStartIndex * FLOATS_PER_VERTEX;
            if (cacheOffset + newVertices.length > __vertexCache.length) {
                trace("TileBatchFast: Error - Partial update would exceed buffer bounds, forcing full rebuild");
                trace("  Tile " + tileId + ": cache offset " + cacheOffset + " + data length " + newVertices.length + " > cache size " + __vertexCache.length);
                __bufferDirty = true;
                return updateBuffers(renderer); // Force full rebuild
            }
            
            // Debug: Print the vertex data being generated
            // trace("TileBatchFast: Generated vertices for tile " + tileId + ":");
            // trace("  Position: (" + tile.x + ", " + tile.y + ") Size: " + tile.width + "x" + tile.height + " Region: " + tile.regionId);
            // trace("  Vertex data (" + newVertices.length + " floats): " + newVertices.slice(0, Std.int(Math.min(10, newVertices.length))));
            
            // Store update for batch processing
            updates.push({
                offset: cacheOffset,
                data: newVertices,
                tileId: tileId
            });
            
            trace("TileBatchFast: Prepared update for tile " + tileId + " at vertex offset " + vertexStartIndex);
        }
        
        // Apply all updates atomically
        trace("TileBatchFast: Applying " + updates.length + " updates to GPU buffer");
        
        // CRITICAL: Set updating flag to prevent rendering during buffer updates
        __isUpdating = true;
        
        for (update in updates) {
            trace("TileBatchFast: Updating tile " + update.tileId + " at offset " + update.offset + " with " + update.data.length + " floats");
            
            // Update the cached vertex data
            for (i in 0...update.data.length) {
                var oldValue = __vertexCache[update.offset + i];
                __vertexCache[update.offset + i] = update.data[i];
                // Only trace significant changes
                if (Math.abs(oldValue - update.data[i]) > 0.001) {
                    trace("  [" + (update.offset + i) + "] " + oldValue + " -> " + update.data[i]);
                }
            }
            
            // Upload partial vertex data to GPU
            trace("TileBatchFast: Uploading to GPU - VBO " + vbo + ", offset " + update.offset + ", " + update.data.length + " floats");
            renderer.uploadVertexDataPartial(vbo, update.offset, update.data);
        }
        
        // Update DisplayObject data only after all GPU uploads are complete
        // CRITICAL: Must update this.vertices to keep DisplayObject in sync with GPU buffer
        // The renderer checks vertices.length to determine if rendering should happen
        this.vertices = new Vertices(__vertexCache);
        this.indices = new Indices(__indexCache);
        
        // CRITICAL: Update render counts to ensure renderer has correct information
        __verticesToRender = Std.int(__vertexCache.length / FLOATS_PER_VERTEX);
        __indicesToRender = __indexCache.length;
        
        // Clear updating flag - rendering can now proceed safely
        __isUpdating = false;
        
        // Clear dirty list
        __dirtyTiles = [];
        
        trace("TileBatchFast: Partial update complete - applied " + updates.length + " updates, " + __verticesToRender + " vertices, " + __indicesToRender + " indices");
    }
    
    /**
     * Render the tile batch
     */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible || !initialized || atlasTexture == null) {
            return;
        }
        
        // CRITICAL: Do not render during buffer updates to prevent flickering
        // if (__isUpdating) {
        //     return;
        // }
        
        // Check if we actually have vertices to render
        if (__verticesToRender == 0 || __indicesToRender == 0) {
            return;
        }
        
        // Debug: Log render state periodically
        // if (frameCount % 60 == 0) { // Every 60 frames (approx 1 second at 60fps)
        //     trace("TileBatchFast: Render debug - VAO: " + vao + ", VBO: " + vbo + ", EBO: " + ebo);
        //     trace("  Vertices to render: " + __verticesToRender + ", Indices: " + __indicesToRender);
        //     trace("  Tiles: " + getTileCount() + ", Cache size: " + __vertexCache.length);
        //     trace("  Buffer dirty: " + __bufferDirty + ", Needs update: " + needsBufferUpdate);
        // }
        
        // Update transformation matrix based on current properties
        updateTransform();
        
        // Create final matrix by combining object matrix with camera matrix
        var finalMatrix = Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        
        // Set uniforms for tile rendering
        uniforms.set("uMatrix", finalMatrix.data);
    }
    
    // Add frame counter for debug timing
    private static var frameCount:Int = 0;
    
    /**
     * Get the number of tiles in the batch
     */
    public function getTileCount():Int {
        var count = 0;
        for (key in tiles.keys()) count++;
        return count;
    }
    
    /**
     * Batch update multiple tiles efficiently
     * @param updates Array of {tileId:Int, x:Float, y:Float, width:Float, height:Float, regionId:Int}
     */
    public function updateTilesBatch(updates:Array<Dynamic>):Void {
        var changeCount = 0;
        
        for (update in updates) {
            if (updateTile(update.tileId, update.x, update.y, update.width, update.height, update.regionId)) {
                changeCount++;
            }
        }
        
    }
    
    /**
     * Get performance statistics
     */
    public function getPerformanceStats():{totalTiles:Int, dirtyTiles:Int, removedTiles:Int, vertexCount:Int, indexCount:Int} {
        return {
            totalTiles: getTileCount(),
            dirtyTiles: __dirtyTiles.length,
            removedTiles: __removedTiles.length,
            vertexCount: __verticesToRender,
            indexCount: __indicesToRender
        };
    }
    
    /**
     * Force a full buffer rebuild (useful for debugging or optimization)
     */
    public function forceRebuild():Void {
        __bufferDirty = true;
        __dirtyTiles = [];
        __removedTiles = [];
        
        if (initialized) {
            needsBufferUpdate = true;
        }
        
        trace("TileBatchFast: Forced full rebuild");
    }
    
    /**
     * TileInstance - stores tile properties for TileBatchFast
     */


    /**
     * Check if a tile exists
     */
    public function hasTile(tileId:Int):Bool {
        return tiles.exists(tileId);
    }
    
    /**
     * Enable or disable partial updates (useful for debugging)
     */
    public function setPartialUpdatesEnabled(enabled:Bool):Void {
        __partialUpdatesEnabled = enabled;
        __consecutivePartialFailures = 0;
        trace("TileBatchFast: Partial updates " + (enabled ? "enabled" : "disabled"));
    }
    
    /**
     * Get whether partial updates are currently enabled
     */
    public function getPartialUpdatesEnabled():Bool {
        return __partialUpdatesEnabled;
    }

    /**
     * Get tile instance (for reading properties)
     */
    public function getTile(tileId:Int):TileInstanceFast {
        return tiles.get(tileId);
    }
    
    /**
     * Get atlas region (for reading properties)
     */
    public function getRegion(regionId:Int):AtlasRegionFast {
        return atlasRegions.get(regionId);
    }
    
    /**
     * Check if a region exists
     */
    public function hasRegion(regionId:Int):Bool {
        return atlasRegions.exists(regionId);
    }
    
    /**
     * Get the number of defined regions
     */
    public function getRegionCount():Int {
        var count = 0;
        for (key in atlasRegions.keys()) count++;
        return count;
    }
}

/**
 * Data structure representing a single tile instance in TileBatchFast
 */
class TileInstanceFast {
    public var x:Float = 0.0;          // World X position
    public var y:Float = 0.0;          // World Y position
    public var width:Float = 1.0;      // Tile width in world units
    public var height:Float = 1.0;     // Tile height in world units
    public var regionId:Int = 0;       // Atlas region ID to use for UV coordinates
    
    public function new() {}
}

/**
 * Data structure representing an atlas region in TileBatchFast
 */
class AtlasRegionFast {
    public var x:Int = 0;              // Atlas X coordinate in pixels
    public var y:Int = 0;              // Atlas Y coordinate in pixels
    public var width:Int = 1;          // Atlas width in pixels
    public var height:Int = 1;         // Atlas height in pixels
    public var u1:Float = 0.0;         // Calculated left UV coordinate
    public var v1:Float = 0.0;         // Calculated top UV coordinate
    public var u2:Float = 1.0;         // Calculated right UV coordinate
    public var v2:Float = 1.0;         // Calculated bottom UV coordinate
    
    public function new() {}
}