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
    
    // Buffer management
    private var __nextTileId:Int = 1; // Auto-incrementing tile ID
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
        
        trace("TileBatch: Created with texture ID=" + texture.id + " size=" + texture.width + "x" + texture.height);
    }
    
    /**
     * Add a tile to the batch
     * @param x World X position
     * @param y World Y position
     * @param width Tile width in world units
     * @param height Tile height in world units
     * @param u1 Left UV coordinate (0.0-1.0)
     * @param v1 Top UV coordinate (0.0-1.0)
     * @param u2 Right UV coordinate (0.0-1.0)
     * @param v2 Bottom UV coordinate (0.0-1.0)
     * @return Tile ID for future reference
     */
    public function addTile(x:Float, y:Float, width:Float, height:Float, u1:Float, v1:Float, u2:Float, v2:Float):Int {
        var tileId = __nextTileId++;
        
        var tile = new TileInstance();
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.u1 = u1;
        tile.v1 = v1;
        tile.u2 = u2;
        tile.v2 = v2;
        
        tiles.set(tileId, tile);
        __bufferDirty = true;
        
        if (initialized) {
            needsBufferUpdate = true;
        }
        
        trace("TileBatch: Added tile " + tileId + " at (" + x + "," + y + ") size=" + width + "x" + height + " UV=(" + u1 + "," + v1 + "," + u2 + "," + v2 + ")");
        return tileId;
    }
    
    /**
     * Add a tile using pixel coordinates in the atlas
     * @param x World X position
     * @param y World Y position
     * @param width Tile width in world units
     * @param height Tile height in world units
     * @param atlasX Atlas X coordinate in pixels
     * @param atlasY Atlas Y coordinate in pixels
     * @param atlasWidth Atlas width in pixels
     * @param atlasHeight Atlas height in pixels
     * @return Tile ID for future reference
     */
    public function addTileFromAtlas(x:Float, y:Float, width:Float, height:Float, 
                                   atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        // Convert pixel coordinates to UV coordinates
        var u1 = atlasX / atlasTexture.width;
        var v1 = atlasY / atlasTexture.height;
        var u2 = (atlasX + atlasWidth) / atlasTexture.width;
        var v2 = (atlasY + atlasHeight) / atlasTexture.height;
        
        // Apply V-coordinate flipping for OpenGL
        var topV = 1.0 - v1;
        var bottomV = 1.0 - v2;
        
        return addTile(x, y, width, height, u1, topV, u2, bottomV);
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
            
            trace("TileBatch: Removed tile " + tileId);
            return true;
        }
        
        trace("TileBatch: Cannot remove tile " + tileId + " - not found");
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
            
            trace("TileBatch: Updated tile " + tileId + " position to (" + x + "," + y + ")");
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
        
        trace("TileBatch: Cleared all tiles");
    }
    
    /**
     * Generate vertex data for a single tile
     */
    private function generateTileVertices(tile:TileInstance):Array<Float> {
        var vertices = [];
        
        // Create quad vertices: top-left, top-right, bottom-right, bottom-left
        // Format: [x, y, z, u, v] per vertex
        
        // Top-left
        vertices.push(tile.x);
        vertices.push(tile.y + tile.height);
        vertices.push(0.0);
        vertices.push(tile.u1);
        vertices.push(tile.v1);
        
        // Top-right
        vertices.push(tile.x + tile.width);
        vertices.push(tile.y + tile.height);
        vertices.push(0.0);
        vertices.push(tile.u2);
        vertices.push(tile.v1);
        
        // Bottom-right
        vertices.push(tile.x + tile.width);
        vertices.push(tile.y);
        vertices.push(0.0);
        vertices.push(tile.u2);
        vertices.push(tile.v2);
        
        // Bottom-left
        vertices.push(tile.x);
        vertices.push(tile.y);
        vertices.push(0.0);
        vertices.push(tile.u1);
        vertices.push(tile.v2);
        
        // Debug: Log UV coordinates for first tile
        if (tile.x == 0 && tile.y == 0) {
            trace("TileBatch: First tile UV coords: u1=" + tile.u1 + ", v1=" + tile.v1 + ", u2=" + tile.u2 + ", v2=" + tile.v2);
            trace("TileBatch: First tile vertices: " + vertices.slice(0, 10).join(","));
        }
        
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
        
        // Debug: Check programInfo texture configuration
        trace("TileBatch: programInfo.textures.length = " + programInfo.textures.length);
        trace("TileBatch: drawable.textures.length = " + textures.length);
        if (textures.length > 0 && textures[0] != null) {
            trace("TileBatch: First texture ID = " + textures[0].id);
        }
        
        trace("TileBatch: Rendering with texture ID=" + atlasTexture.id + ", vertices=" + __verticesToRender + ", indices=" + __indicesToRender);
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
}

/**
 * Data structure representing a single tile instance
 */
class TileInstance {
    public var x:Float = 0.0;          // World X position
    public var y:Float = 0.0;          // World Y position
    public var width:Float = 1.0;      // Tile width in world units
    public var height:Float = 1.0;     // Tile height in world units
    public var u1:Float = 0.0;         // Left UV coordinate
    public var v1:Float = 0.0;         // Top UV coordinate
    public var u2:Float = 1.0;         // Right UV coordinate
    public var v2:Float = 1.0;         // Bottom UV coordinate
    
    public function new() {}
}