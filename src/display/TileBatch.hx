package display;

import cpp.Float32;
import cpp.UInt32;
import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import Texture;
import math.Matrix;
import data.Vertices;
import data.Indices;
import display.Tile;
import display.AtlasRegion;

/**
 * TileBatch - Primitive tile batching system
 * 
 * Core functionality:
 * - Batch multiple tiles using the same texture
 * - Free-form positioning (no grid constraints)
 * - Add/remove individual tiles by ID
 * - Automatic vertex buffer management
 * - Base class for Tilemap and other tile-based systems
 */
class TileBatch extends DisplayObject {
    
    // Dense array storage - tiles at index = tileId
    public var tiles:Array<Tile> = [];
    
    // Atlas regions - dense array storage
    public var atlasRegions:Array<AtlasRegion> = [];
    
    public var atlasTexture:Texture = null;
    
    // Buffer management
    private var __dirtyTiles:Map<Int, Bool> = new Map(); // Dirty tile tracking (Map prevents duplicates)
    private var __initialized:Bool = false;  // First-time initialization flag
    private var __needsRebuild:Bool = false; // Structure changed (add/remove)
    private var __vertexCache:Array<Float32> = [];
    private var __indexCache:Array<UInt32> = [];
    
    // Vertex mapping for partial updates (tileId -> vertex offset in buffer)
    private var __tileVertexOffsets:Array<Int> = []; // tileId -> starting vertex index
    private var __maxTiles:Int = 1000; // Maximum tile capacity
    
    /**
     * Create a new TileBatch
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     * @param maxTiles Maximum number of tiles this batch can hold (default 1000)
     */
    public function new(programInfo:ProgramInfo, texture:Texture, maxTiles:Int = 1000) {
        this.atlasTexture = texture;
        this.__maxTiles = maxTiles;
        
        // Pre-allocate vertex and index buffers (prevents reallocation)
        // Each tile = 4 vertices * 5 floats = 20 floats
        // Each tile = 2 triangles * 3 indices = 6 indices
        __vertexCache = [for (i in 0...(maxTiles * 20)) 0.0];
        __indexCache = [for (i in 0...(maxTiles * 6)) 0];
        
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
     * @return Region ID (array index) for use in addTile
     */
    public function defineRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        var region = new AtlasRegion();
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
        
        // Add to array, index becomes the region ID
        var regionId = atlasRegions.length;
        atlasRegions.push(region);
        
        if (regionId <= 3) { // Only trace first 3 regions (button parts)
            trace("TileBatch: defineRegion ID=" + regionId + " at (" + atlasX + "," + atlasY + "," + atlasWidth + "," + atlasHeight + ")");
            trace("  Texture size: " + atlasTexture.width + "x" + atlasTexture.height);
            trace("  UVs: (" + region.u1 + "," + region.v1 + ") to (" + region.u2 + "," + region.v2 + ")");
        }
        
        return regionId;
    }
    
    /**
     * Add a tile to the batch using a predefined atlas region
     * @param x World X position
     * @param y World Y position
     * @param width Tile width in world units
     * @param height Tile height in world units
     * @param regionId Atlas region ID (from defineRegion)
     * @return Tile ID for future reference (array index)
     */
    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        if (regionId < 0 || regionId >= atlasRegions.length) {
            trace("TileBatch: Error - Region ID " + regionId + " does not exist!");
            return -1;
        }
        
        // Create new tile ID (always append - swap-and-pop keeps array dense)
        var tileId:Int = tiles.length;
        
        var tile = new Tile(this);
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.regionId = regionId;
        
        // Set tile at index (grow array if needed)
        if (tileId >= tiles.length) {
            tiles.push(tile);
        } else {
            tiles[tileId] = tile;
        }
        
        // Adding a tile requires rebuild (render count changes)
        __needsRebuild = true;
        
        if (active) {
            needsBufferUpdate = true;
        }
        
        return tileId;
    }

    // TODO: Placeholder for adding existing Tile instances
    public function addTileInstance(tile:Tile):Void {
        if (tile == null) return;

        // Create new tile ID (always append - swap-and-pop keeps array dense)
        var tileId:Int = tiles.length;
        
        if (tileId >= tiles.length) {
            tiles.push(tile);
        } else {
            tiles[tileId] = tile;
        }
        
        // Adding a tile requires rebuild (render count changes)
        __needsRebuild = true;

        if (active) {
            needsBufferUpdate = true;
        }
    }
    
    /**
     * Remove a tile from the batch using swap-and-pop
     * Swaps the removed tile with the last tile, then pops
     * This avoids full buffer rebuilds by maintaining dense packing
     * @param tileId Tile ID to remove
     * @return True if tile was found and removed
     */
    public function removeTile(tileId:Int):Bool {
        if (tileId < 0 || tileId >= tiles.length || tiles[tileId] == null) {
            return false;
        }
        
        var lastIndex = tiles.length - 1;
        
        // Removing a tile requires rebuild (render count changes)
        if (tileId == lastIndex) {
            tiles.pop();
        } else {
            // Swap with last tile and pop
            tiles[tileId] = tiles[lastIndex];
            tiles.pop();
        }
        
        // Trigger rebuild to repack buffer
        __needsRebuild = true;
        
        if (active) {
            needsBufferUpdate = true;
        }
        return true;
    }
    
	public function removeTileInstance(tile:Tile):Bool {
		for (i in 0...tiles.length) {
			if (tiles[i] == tile) {
				return removeTile(i);
			}
		}
		return false;
	}
    
    /**
     * Update a tile's position
     * @param tileId Tile ID to update
     * @param x New world X position
     * @param y New world Y position
     * @return True if tile was found and updated
     */
    public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
        if (tileId < 0 || tileId >= tiles.length || tiles[tileId] == null) {
            return false;
        }
        
        var tile = tiles[tileId];
        tile.x = x;
        tile.y = y;
        
        // Position change only - use fast partial update
        __dirtyTiles.set(tileId, true);
        
        if (active) {
            needsBufferUpdate = true;
        }
        
        return true;
    }
    
    /**
     * Get a tile by ID
     * @param tileId Tile ID
     * @return Tile instance or null if not found
     */
    public function getTile(tileId:Int):Tile {
        if (tileId < 0 || tileId >= tiles.length) {
            return null;
        }
        return tiles[tileId];
    }
    
    /**
     * Clear all tiles from the batch
     */
    public function clear():Void {
        tiles = [];
        __needsRebuild = true;
        
        if (active) {
            needsBufferUpdate = true;
        }
    }
    
    /**
     * Generate vertex data directly into cache (no allocations!)
     * Writes 20 floats (4 vertices * 5 components) directly to __vertexCache
     */
    private inline function generateTileVerticesAt(tile:Tile, offset:Int):Void {
        // Get UV coordinates from the atlas region (using array index)
        var region = atlasRegions[tile.regionId];
        if (region == null) {
            trace("TileBatch: Warning - Region ID " + tile.regionId + " not found, skipping tile");
            return; // Skip this tile instead of using broken UVs
        }
        
        // IMPORTANT: Flip V coordinates to compensate for Y-axis flip in Camera
        // The Camera now has (0,0) at top-left with Y increasing downward
        // So we need to flip the texture V coordinates to render correctly
        var v1 = region.v2;  // Swap V coordinates
        var v2 = region.v1;  // Swap V coordinates
        
        var x = tile.x + tile.offsetX;
        var y = tile.y + tile.offsetY;
        var w = tile.width;
        var h = tile.height;
        
        // Write vertices directly at offset (no allocations)
        var idx = offset;
        
        // Top-left vertex (x, y+h, z, u1, v1)
        __vertexCache[idx++] = x;
        __vertexCache[idx++] = y + h;
        __vertexCache[idx++] = 0.0;
        __vertexCache[idx++] = region.u1;
        __vertexCache[idx++] = v1;
        
        // Top-right vertex (x+w, y+h, z, u2, v1)
        __vertexCache[idx++] = x + w;
        __vertexCache[idx++] = y + h;
        __vertexCache[idx++] = 0.0;
        __vertexCache[idx++] = region.u2;
        __vertexCache[idx++] = v1;
        
        // Bottom-right vertex (x+w, y, z, u2, v2)
        __vertexCache[idx++] = x + w;
        __vertexCache[idx++] = y;
        __vertexCache[idx++] = 0.0;
        __vertexCache[idx++] = region.u2;
        __vertexCache[idx++] = v2;
        
        // Bottom-left vertex (x, y, z, u1, v2)
        __vertexCache[idx++] = x;
        __vertexCache[idx++] = y;
        __vertexCache[idx++] = 0.0;
        __vertexCache[idx++] = region.u1;
        __vertexCache[idx++] = v2;
    }
    
    /**
     * Initialize static index buffer - indices never change, only vertex count
     * Called once during first update
     */
    private function initializeIndices():Void {
        var vertexIndex:UInt = 0;
        
        // Generate indices for maximum tile capacity
        for (i in 0...__maxTiles) {
            var indexOffset = i * 6;
            
            // Two triangles per quad (CCW winding)
            __indexCache[indexOffset + 0] = vertexIndex + 0;  // Top-left
            __indexCache[indexOffset + 1] = vertexIndex + 1;  // Top-right
            __indexCache[indexOffset + 2] = vertexIndex + 2;  // Bottom-right
            
            __indexCache[indexOffset + 3] = vertexIndex + 0;  // Top-left
            __indexCache[indexOffset + 4] = vertexIndex + 2;  // Bottom-right
            __indexCache[indexOffset + 5] = vertexIndex + 3;  // Bottom-left
            
            vertexIndex += 4;
        }
        
        // Upload indices once (never change)
        this.indices = new Indices(__indexCache);
    }
    
    /**
     * Compact tiles and rebuild - needed when tiles are added/removed
     * Tiles are repositioned in buffer to maintain dense packing
     */
    private function compactAndRebuild():Void {
        var tileCount = 0;
        
        // Rebuild entire buffer (tiles may have shifted due to swap-and-pop)
        for (i in 0...tiles.length) {
            var tile = tiles[i];
            if (tile == null || !tile.visible) {
                continue;
            }
            
            // Calculate where this tile goes in the buffer
            var vertexOffset = tileCount * 20;
            __tileVertexOffsets[i] = vertexOffset;
            
            // Write vertices at this position
            generateTileVerticesAt(tile, vertexOffset);
            
            tileCount++;
        }
        
        // Update render counts
        __verticesToRender = tileCount * 4;
        __indicesToRender = tileCount * 6;
        
        // Upload vertex data (indices never change)
        this.vertices = new Vertices(__vertexCache);
    }
    
    /**
     * Partial update - only regenerate vertices for dirty tiles (position/UV changes)
     * ONLY works when tile positions in array didn't change
     */
    private function updateDirtyTiles():Void {
        // For each dirty tile, regenerate its vertices at known offset
        for (tileId in __dirtyTiles.keys()) {
            if (tileId < 0 || tileId >= tiles.length) continue;
            
            var tile = tiles[tileId];
            if (tile == null || !tile.visible) continue;
            
            var vertexOffset = __tileVertexOffsets[tileId];
            if (vertexOffset < 0) continue; // Tile not in buffer
            
            // Regenerate vertices for this tile only
            generateTileVerticesAt(tile, vertexOffset);
        }
        
        // Upload modified vertex data
        this.vertices = new Vertices(__vertexCache);
    }
    
    /**
     * Update buffers when needed
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!active || atlasTexture == null) return;
        
        // First-time initialization (only once)
        if (!__initialized) {
            initializeIndices();
            compactAndRebuild(); // Generate initial vertices
            // First upload - allocate GPU buffers with all data
            renderer.uploadData(this);
            __initialized = true;
            __needsRebuild = false;
            __dirtyTiles.clear();
            needsBufferUpdate = false;
            return;
        }
        
        // Handle structural changes (add/remove tiles)
        if (__needsRebuild) {
            compactAndRebuild();
            // Partial upload - only send active tile data
            var activeFloats = __verticesToRender * 5;
            renderer.uploadPartialData(this, 0, activeFloats);
            __needsRebuild = false;
            __dirtyTiles.clear(); // Rebuild covers all tiles
            needsBufferUpdate = false;
            return;
        }
        
        // Handle position updates (fast path - partial upload)
        if (Lambda.count(__dirtyTiles) > 0) {
            updateDirtyTiles();
            // Partial upload - only send active tile data
            var activeFloats = __verticesToRender * 5;
            renderer.uploadPartialData(this, 0, activeFloats);
            __dirtyTiles.clear();
            needsBufferUpdate = false;
        }
    }
    
    /**
     * Render the tile batch
     */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible || !active || atlasTexture == null) {
            return;
        }
        
        // Check if we actually have vertices to render
        if (__verticesToRender == 0 || __indicesToRender == 0) {
            trace("TileBatch: Skipping render - no vertices (__verticesToRender=" + __verticesToRender + ", __indicesToRender=" + __indicesToRender + ")");
            return;
        }
        
        // Update transformation matrix based on current properties
        updateTransform();
        
        // Create final matrix by combining object matrix with camera matrix
        var finalMatrix = Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        
        // Set uniforms for tile rendering
        uniforms.set("uMatrix", finalMatrix.data);
    }
    
    /**
     * Get the number of tiles in the batch (counts non-null tiles)
     */
    public function getTileCount():Int {
        var count = 0;
        for (i in 0...tiles.length) {
            if (tiles[i] != null) count++;
        }
        return count;
    }
    
    /**
     * Check if a tile exists
     */
    public function hasTile(tileId:Int):Bool {
        return tileId >= 0 && tileId < tiles.length && tiles[tileId] != null;
    }
    
    /**
     * Get atlas region (for reading properties)
     */
    public function getRegion(regionId:Int):AtlasRegion {
        if (regionId < 0 || regionId >= atlasRegions.length) {
            return null;
        }
        return atlasRegions[regionId];
    }
    
    /**
     * Check if a region exists
     */
    public function hasRegion(regionId:Int):Bool {
        return regionId >= 0 && regionId < atlasRegions.length;
    }
    
    /**
     * Get the number of defined regions
     */
    public function getRegionCount():Int {
        return atlasRegions.length;
    }
}

/**
 * Data structure representing an atlas region
 */
// class AtlasRegion {
//     public var x:Int = 0;              // Atlas X coordinate in pixels
//     public var y:Int = 0;              // Atlas Y coordinate in pixels
//     public var width:Int = 1;          // Atlas width in pixels
//     public var height:Int = 1;         // Atlas height in pixels
//     public var u1:Float = 0.0;         // Calculated left UV coordinate
//     public var v1:Float = 0.0;         // Calculated top UV coordinate
//     public var u2:Float = 1.0;         // Calculated right UV coordinate
//     public var v2:Float = 1.0;         // Calculated bottom UV coordinate
    
//     public function new() {}
// }