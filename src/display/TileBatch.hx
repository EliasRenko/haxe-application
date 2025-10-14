package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import Texture;
import math.Matrix;

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
    
    // Tile data structure
    public var tiles:Map<Int, TileInstance> = new Map(); // tileId -> TileInstance
    public var atlasTexture:Texture = null;
    public var atlasRegions:Map<Int, AtlasRegion> = new Map(); // regionId -> AtlasRegion
    
    // Buffer management
    private var __nextTileId:Int = 1; // Auto-incrementing tile ID
    private var __nextRegionId:Int = 1; // Auto-incrementing region ID
    private var __bufferDirty:Bool = true;
    private var __vertexCache:Array<Float> = [];
    private var __indexCache:Array<UInt> = [];
    
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
        
        var tile = new TileInstance();
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.regionId = regionId;
        
        tiles.set(tileId, tile);
        __bufferDirty = true;
        
        if (initialized) {
            needsBufferUpdate = true;
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
            __bufferDirty = true;
            
            if (initialized) {
                needsBufferUpdate = true;
            }
            return true;
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
    private function generateTileVertices(tile:TileInstance):Array<Float> {
        var vertices = [];
        
        // Get UV coordinates from the atlas region
        var region = atlasRegions.get(tile.regionId);
        if (region == null) {
            trace("TileBatch: Warning - Region ID " + tile.regionId + " not found, using default UVs");
            // Use default full texture UVs as fallback
            region = new AtlasRegion();
            region.u1 = 0.0;
            region.v1 = 1.0;
            region.u2 = 1.0;
            region.v2 = 0.0;
        }
        
        // Debug the UV coordinates being used for rendering
        trace("TileBatch: generateTileVertices DEBUG for tile regionId=" + tile.regionId);
        trace("  Region UV stored: (" + region.u1 + "," + region.v1 + ") to (" + region.u2 + "," + region.v2 + ")");
        trace("  Final vertex UV (no flip): (" + region.u1 + "," + region.v1 + ") to (" + region.u2 + "," + region.v2 + ")");
        
        // Create quad vertices: top-left, top-right, bottom-right, bottom-left
        // Format: [x, y, z, u, v] per vertex
        // Use UV coordinates directly since texture is loaded with correct orientation
        
        // Top-left
        vertices.push(tile.x);
        vertices.push(tile.y + tile.height);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(region.v1);  // Use V directly
        
        // Top-right
        vertices.push(tile.x + tile.width);
        vertices.push(tile.y + tile.height);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(region.v1);  // Use V directly
        
        // Bottom-right
        vertices.push(tile.x + tile.width);
        vertices.push(tile.y);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(region.v2);  // Use V directly
        
        // Bottom-left
        vertices.push(tile.x);
        vertices.push(tile.y);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(region.v2);  // Use V directly
        
        return vertices;
    }
    
    /**
     * Generate mesh data for all tiles
     */
    private function generateMesh():Void {
        __vertexCache = [];
        __indexCache = [];
        
        var vertexIndex:UInt = 0;
        
        // Generate mesh for each tile
        for (tileId in tiles.keys()) {
            var tile = tiles.get(tileId);
            
            // Generate vertices for this tile
            var tileVertices = generateTileVertices(tile);
            for (vertex in tileVertices) {
                __vertexCache.push(vertex);
            }
            
            // Create indices for two triangles (quad)
            __indexCache.push(vertexIndex + 0);  // Top-left
            __indexCache.push(vertexIndex + 1);  // Top-right
            __indexCache.push(vertexIndex + 2);  // Bottom-right
            
            __indexCache.push(vertexIndex + 0);  // Top-left
            __indexCache.push(vertexIndex + 2);  // Bottom-right
            __indexCache.push(vertexIndex + 3);  // Bottom-left
            
            vertexIndex += 4;
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
     * Update buffers when needed
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!initialized || atlasTexture == null) return;
        
        if (__bufferDirty) {
            trace("TileBatch: Updating buffers");
            generateMesh();
            
            renderer.uploadVertexData(vao, vbo, this.vertices.data);
            renderer.uploadIndexData(ebo, this.indices.data);
            renderer.setupVertexAttributes(programInfo);
            
            __bufferDirty = false;
            needsBufferUpdate = false;
            
            trace("TileBatch: Buffer update complete");
        }
    }
    
    /**
     * Render the tile batch
     */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible || !initialized || atlasTexture == null) {
            return;
        }
        
        // Check if we actually have vertices to render
        if (__verticesToRender == 0 || __indicesToRender == 0) {
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
     * Get the number of tiles in the batch
     */
    public function getTileCount():Int {
        var count = 0;
        for (key in tiles.keys()) count++;
        return count;
    }
    
    /**
     * Check if a tile exists
     */
    public function hasTile(tileId:Int):Bool {
        return tiles.exists(tileId);
    }
    
    /**
     * Get tile instance (for reading properties)
     */
    public function getTile(tileId:Int):TileInstance {
        return tiles.get(tileId);
    }
    
    /**
     * Get atlas region (for reading properties)
     */
    public function getRegion(regionId:Int):AtlasRegion {
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
 * Data structure representing a single tile instance
 */
class TileInstance {
    public var x:Float = 0.0;          // World X position
    public var y:Float = 0.0;          // World Y position
    public var width:Float = 1.0;      // Tile width in world units
    public var height:Float = 1.0;     // Tile height in world units
    public var regionId:Int = 0;       // Atlas region ID to use for UV coordinates
    
    public function new() {}
}

/**
 * Data structure representing an atlas region
 */
class AtlasRegion {
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