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
import display.TileStreaming;
import display.AtlasRegion;

/**
 * TileBatchStreaming - High-performance streaming tile batch using ring buffer technique
 * 
 * Optimized for use cases with frequent updates (particles, dynamic enemies, etc.)
 * Uses persistent buffer mapping and ring buffer strategy for minimal GPU overhead.
 * 
 * Key differences from standard TileBatch:
 * - Uses glMapBufferRange with GL_MAP_UNSYNCHRONIZED_BIT for direct memory writes
 * - Implements ring buffer with automatic orphaning when buffer fills
 * - Pre-allocates large buffer (configurable, default 4MB)
 * - Minimal API calls per frame (1 map + 1 unmap + 1 draw)
 * 
 * Best for:
 * - Particle systems (1000+ particles, all updating every frame)
 * - Dynamic enemy batches (100+ entities with frequent movement)
 * - Any scenario where >50% of tiles update per frame
 * 
 * Not ideal for:
 * - Static tilemaps (use standard TileBatch with per-tile uploads)
 * - Sparse updates (<10% tiles dirty per frame)
 */
class TileBatchStreaming extends DisplayObject {
    
    // Dense array storage - tiles at index = tileId
    public var tiles:Array<TileStreaming> = [];
    
    // Atlas regions - dense array storage
    public var atlasRegions:Array<AtlasRegion> = [];
    
    public var atlasTexture:Texture = null;
    
    // Ring buffer state
    private var __cursor:Int = 0;           // Current write position in buffer (in bytes)
    private var __bufferSize:Int = 0;       // Total buffer size in bytes
    private var __alignment:Int = 64;       // Memory alignment (64 bytes for optimal GPU performance)
    
    // CPU-side staging buffer for gathering visible tiles
    private var __stagingBuffer:Array<Float32> = [];
    private var __maxStagingFloats:Int = 0;
    
    // Index buffer (static, never changes)
    private var __indexCache:Array<UInt32> = [];
    private var __maxTiles:Int = 1000;
    
    // Initialization flag
    private var __initialized:Bool = false;
    
    /**
     * Create a new streaming TileBatch with ring buffer
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     * @param maxTiles Maximum number of tiles this batch can hold (default 1000)
     * @param bufferSizeMB Size of ring buffer in megabytes (default 4MB)
     */
    public function new(programInfo:ProgramInfo, texture:Texture, maxTiles:Int = 1000, bufferSizeMB:Int = 4) {
        this.atlasTexture = texture;
        this.__maxTiles = maxTiles;
        
        // Calculate buffer size
        // Each tile = 4 vertices × 5 floats × 4 bytes = 80 bytes
        // With alignment, roughly 128 bytes per tile
        // For 4MB buffer: ~32,000 tiles capacity (way more than maxTiles)
        __bufferSize = bufferSizeMB * 1024 * 1024;
        
        // Pre-allocate staging buffer (CPU-side)
        // This is where we gather visible tile data before uploading
        __maxStagingFloats = maxTiles * 20; // 4 vertices × 5 floats per tile
        __stagingBuffer = [for (i in 0...__maxStagingFloats) 0.0];
        
        // Pre-allocate index cache
        __indexCache = [for (i in 0...(maxTiles * 6)) 0];
        
        // Start with empty vertices (will be initialized on first update)
        var emptyVertices = new Vertices([]);
        var emptyIndices = new Indices([]);
        
        super(programInfo, emptyVertices, emptyIndices);
        
        // Set OpenGL properties
        mode = GL.TRIANGLES;
        
        // Make sure the batch is active and visible
        active = true;
        visible = true;
        
        // Set proper alpha blending for transparent textures
        blendFactors = {
            source: GL.SRC_ALPHA,
            destination: GL.ONE_MINUS_SRC_ALPHA
        };
        
        // Set the texture for the display object
        setTexture(texture);
        
        trace("TileBatchStreaming: Created with " + bufferSizeMB + "MB ring buffer (" + __bufferSize + " bytes)");
    }
    
    /**
     * Define an atlas region using pixel coordinates
     */
    public function defineRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        var region = new AtlasRegion();
        region.x = atlasX;
        region.y = atlasY;
        region.width = atlasWidth;
        region.height = atlasHeight;
        
        // Convert pixel coordinates to UV coordinates
        region.u1 = atlasX / atlasTexture.width;
        region.v1 = atlasY / atlasTexture.height;
        region.u2 = (atlasX + atlasWidth) / atlasTexture.width;
        region.v2 = (atlasY + atlasHeight) / atlasTexture.height;
        
        var regionId = atlasRegions.length;
        atlasRegions.push(region);
        
        return regionId;
    }
    
    /**
     * Add a tile to the batch
     */
    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        if (regionId < 0 || regionId >= atlasRegions.length) {
            trace("TileBatchStreaming: Error - Region ID " + regionId + " does not exist!");
            return -1;
        }
        
        var tileId:Int = tiles.length;
        
        var tile = new TileStreaming(regionId);
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        
        tiles.push(tile);
        
        if (active) {
            needsBufferUpdate = true;
        }
        
        return tileId;
    }
    
    /**
     * Add existing tile instance
     */
    public function addTileInstance(tile:TileStreaming):Void {
        if (tile == null) return;
        tiles.push(tile);
        if (active) {
            needsBufferUpdate = true;
        }
    }
    
    /**
     * Remove a tile (swap-and-pop for dense packing)
     */
    public function removeTile(tileId:Int):Bool {
        if (tileId < 0 || tileId >= tiles.length || tiles[tileId] == null) {
            return false;
        }
        
        var lastIndex = tiles.length - 1;
        
        if (tileId == lastIndex) {
            tiles.pop();
        } else {
            tiles[tileId] = tiles[lastIndex];
            tiles.pop();
        }
        
        if (active) {
            needsBufferUpdate = true;
        }
        return true;
    }
    
    /**
     * Remove tile by instance
     */
    public function removeTileInstance(tile:TileStreaming):Bool {
        for (i in 0...tiles.length) {
            if (tiles[i] == tile) {
                return removeTile(i);
            }
        }
        return false;
    }
    
    /**
     * Update a tile's position
     * Note: In streaming mode, all visible tiles are re-uploaded every frame anyway,
     * so this just marks the batch as needing an update
     */
    public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
        if (tileId < 0 || tileId >= tiles.length || tiles[tileId] == null) {
            return false;
        }
        
        var tile = tiles[tileId];
        tile.x = x;
        tile.y = y;
        
        if (active) {
            needsBufferUpdate = true;
        }
        
        return true;
    }
    
    /**
     * Get a tile by ID
     */
    public function getTile(tileId:Int):TileStreaming {
        if (tileId < 0 || tileId >= tiles.length) {
            return null;
        }
        return tiles[tileId];
    }
    
    /**
     * Clear all tiles
     */
    public function clear():Void {
        tiles = [];
        if (active) {
            needsBufferUpdate = true;
        }
    }
    
    /**
     * Generate vertices for a tile directly into staging buffer
     * Returns number of floats written
     */
    private inline function generateTileVertices(tile:TileStreaming, stagingOffset:Int):Int {
        var region = atlasRegions[tile.regionId];
        if (region == null) return 0;
        
        // Flip V coordinates for camera coordinate system
        var v1 = region.v2;
        var v2 = region.v1;
        
        var x = tile.x + tile.offsetX;
        var y = tile.y + tile.offsetY;
        var w = tile.width;
        var h = tile.height;
        
        var idx = stagingOffset;
        
        // Top-left vertex
        __stagingBuffer[idx++] = x;
        __stagingBuffer[idx++] = y + h;
        __stagingBuffer[idx++] = 0.0;
        __stagingBuffer[idx++] = region.u1;
        __stagingBuffer[idx++] = v1;
        
        // Top-right vertex
        __stagingBuffer[idx++] = x + w;
        __stagingBuffer[idx++] = y + h;
        __stagingBuffer[idx++] = 0.0;
        __stagingBuffer[idx++] = region.u2;
        __stagingBuffer[idx++] = v1;
        
        // Bottom-right vertex
        __stagingBuffer[idx++] = x + w;
        __stagingBuffer[idx++] = y;
        __stagingBuffer[idx++] = 0.0;
        __stagingBuffer[idx++] = region.u2;
        __stagingBuffer[idx++] = v2;
        
        // Bottom-left vertex
        __stagingBuffer[idx++] = x;
        __stagingBuffer[idx++] = y;
        __stagingBuffer[idx++] = 0.0;
        __stagingBuffer[idx++] = region.u1;
        __stagingBuffer[idx++] = v2;
        
        return 20; // 4 vertices × 5 floats
    }
    
    /**
     * Initialize static index buffer
     */
    private function initializeIndices():Void {
        var vertexIndex:UInt = 0;
        
        for (i in 0...__maxTiles) {
            var indexOffset = i * 6;
            
            __indexCache[indexOffset + 0] = vertexIndex + 0;
            __indexCache[indexOffset + 1] = vertexIndex + 1;
            __indexCache[indexOffset + 2] = vertexIndex + 2;
            
            __indexCache[indexOffset + 3] = vertexIndex + 0;
            __indexCache[indexOffset + 4] = vertexIndex + 2;
            __indexCache[indexOffset + 5] = vertexIndex + 3;
            
            vertexIndex += 4;
        }
        
        this.indices = new Indices(__indexCache);
    }
    
    /**
     * Update buffers using ring buffer streaming technique
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!active || atlasTexture == null) return;
        
        // First-time initialization
        if (!__initialized) {
            initializeIndices();
            
            // Initialize ring buffer - allocate large GPU buffer with NULL data
            renderer.initializeStreamingBuffer(this, __bufferSize);
            
            __initialized = true;
            trace("TileBatchStreaming: Initialized " + (__bufferSize / (1024 * 1024)) + "MB streaming buffer");
        }
        
        // Gather all visible tiles into staging buffer
        var stagingOffset = 0;
        var tileCount = 0;
        
        for (i in 0...tiles.length) {
            var tile = tiles[i];
            if (tile == null || !tile.visible) continue;
            
            // Generate vertices directly into staging buffer
            var floatsWritten = generateTileVertices(tile, stagingOffset);
            stagingOffset += floatsWritten;
            tileCount++;
        }
        
        if (tileCount == 0) {
            __verticesToRender = 0;
            __indicesToRender = 0;
            needsBufferUpdate = false;
            return;
        }
        
        // Calculate bytes needed (with alignment)
        var bytes = stagingOffset * 4; // floats to bytes
        var aligned = bytes + (bytes % __alignment);
        
        // Stream data to GPU using ring buffer
        var bufferOffset = renderer.streamToBuffer(this, __stagingBuffer, stagingOffset, aligned, __cursor, __bufferSize);
        
        // Store buffer offset for rendering (GPU will read from this offset)
        this.bufferOffset = bufferOffset;
        
        // Update cursor for next frame
        __cursor = bufferOffset + aligned;
        
        // Update render counts
        __verticesToRender = tileCount * 4;
        __indicesToRender = tileCount * 6;
        
        needsBufferUpdate = false;
    }
    
    /**
     * Render the tile batch
     */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible || !active || atlasTexture == null) {
            trace("TileBatchStreaming.render: Early exit - visible=" + visible + " active=" + active + " atlasTexture=" + (atlasTexture != null));
            return;
        }
        
        if (__verticesToRender == 0 || __indicesToRender == 0) {
            trace("TileBatchStreaming.render: No geometry - verticesToRender=" + __verticesToRender + " indicesToRender=" + __indicesToRender);
            return;
        }
        
        trace("TileBatchStreaming.render: Rendering " + __verticesToRender + " vertices, " + __indicesToRender + " indices");
        
        updateTransform();
        
        var finalMatrix = Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        
        uniforms.set("uMatrix", finalMatrix.data);
    }
    
    // Utility methods
    
    public function getTileCount():Int {
        var count = 0;
        for (i in 0...tiles.length) {
            if (tiles[i] != null) count++;
        }
        return count;
    }
    
    public function hasTile(tileId:Int):Bool {
        return tileId >= 0 && tileId < tiles.length && tiles[tileId] != null;
    }
    
    public function getRegion(regionId:Int):AtlasRegion {
        if (regionId < 0 || regionId >= atlasRegions.length) {
            return null;
        }
        return atlasRegions[regionId];
    }
    
    public function hasRegion(regionId:Int):Bool {
        return regionId >= 0 && regionId < atlasRegions.length;
    }
    
    public function getRegionCount():Int {
        return atlasRegions.length;
    }
}

