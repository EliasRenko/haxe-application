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

/**
 * TileBatch - Primitive orphaning renderer
 * 
 * Strategy:
 * - Allocate buffer once for MAX_TILES capacity (GL_STREAM_DRAW)
 * - Pre-generate all indices (uploaded once with GL_STATIC_DRAW)
 * - Every frame: take tile data and build vertex array
 * - Orphan buffer with glBufferData(NULL, size, GL_STREAM_DRAW)
 * - Upload actual data with glBufferFloatArray()
 * - Draw using actual vertex/index counts
 * 
 * This prevents GPU stalls by allowing the driver to allocate new buffer
 * regions while the GPU is still reading from old ones.
 */
class TileBatch extends DisplayObject {
    
    // Maximum tile capacity (buffer allocated for this many tiles)
    private static inline var MAX_TILES:Int = 1000;
    
    public var atlasTexture:Texture = null;
    public var atlasRegions:Map<Int, AtlasRegion> = new Map(); // regionId -> AtlasRegion
    
    // Current tile data (set each frame)
    //private var __currentTileData:Array<{x:Float, y:Float, width:Float, height:Float, regionId:Int, visible:Bool}> = [];
    
    // Buffer management
    private var __nextRegionId:Int = 1; // Auto-incrementing region ID
    private var __bufferCapacity:Int = 0; // Current buffer capacity in tiles
    
    /**
     * Create a new TileBatch
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     */
    public function new(programInfo:ProgramInfo, texture:Texture) {
        this.atlasTexture = texture;
        
        // Start with empty vertices but pre-generate indices for MAX_TILES
        var emptyVertices = new Vertices([]);
        var indices = generateIndices(MAX_TILES);
        
        super(programInfo, emptyVertices, indices);
        
        // Set OpenGL properties
        mode = GL.TRIANGLES;
        
        // Set proper alpha blending for transparent textures
        blendFactors = {
            source: GL.SRC_ALPHA,
            destination: GL.ONE_MINUS_SRC_ALPHA
        };
        
        // Set the texture for the display object
        setTexture(texture);
        
        __bufferCapacity = 0; // Will be allocated on first init
    }
    
    /**
     * Pre-generate all indices for maximum tile capacity
     * Indices never change, so we generate them once
     */
    private function generateIndices(tileCount:Int):Indices {
        var indices:Array<UInt32> = [];
        
        for (i in 0...tileCount) {
            var vertexIndex:UInt32 = i * 4;
            
            // Triangle 1
            indices.push(vertexIndex + 0);  // Top-left
            indices.push(vertexIndex + 1);  // Top-right
            indices.push(vertexIndex + 2);  // Bottom-right
            
            // Triangle 2
            indices.push(vertexIndex + 0);  // Top-left
            indices.push(vertexIndex + 2);  // Bottom-right
            indices.push(vertexIndex + 3);  // Bottom-left
        }
        
        return new Indices(indices);
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
        
        if (regionId <= 3) { // Only trace first 3 regions (button parts)
            trace("TileBatch: defineRegion ID=" + regionId + " at (" + atlasX + "," + atlasY + "," + atlasWidth + "," + atlasHeight + ")");
            trace("  Texture size: " + atlasTexture.width + "x" + atlasTexture.height);
            trace("  UVs: (" + region.u1 + "," + region.v1 + ") to (" + region.u2 + "," + region.v2 + ")");
        }
        atlasRegions.set(regionId, region);
        
        return regionId;
    }
    
    /**
     * Generate vertex data for a single tile
     */
    private function generateTileVertices(tileData:{x:Float, y:Float, width:Float, height:Float, regionId:Int, visible:Bool}):Void {
        //var vertices = [];
        
        // Get UV coordinates from the atlas region
        var region = atlasRegions.get(tileData.regionId);
        if (region == null) {
            trace("TileBatch: Warning - Region ID " + tileData.regionId + " not found, using default UVs");
            // Use default full texture UVs as fallback
            region = new AtlasRegion();
            region.u1 = 0.0;
            region.v1 = 1.0;
            region.u2 = 1.0;
            region.v2 = 0.0;
        }
        
        // IMPORTANT: Flip V coordinates to compensate for Y-axis flip in Camera
        // The Camera now has (0,0) at top-left with Y increasing downward
        // So we need to flip the texture V coordinates to render correctly
        // DO NOT CHANGE - this ensures tiles render with correct orientation
        var v1 = region.v2;  // Swap V coordinates
        var v2 = region.v1;  // Swap V coordinates
        
        // Create quad vertices: top-left, top-right, bottom-right, bottom-left
        // Format: [x, y, z, u, v] per vertex
        
        // Top-left
        vertices.push(tileData.x);
        vertices.push(tileData.y + tileData.height);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(v1);  // Flipped V
        
        // Top-right
        vertices.push(tileData.x + tileData.width);
        vertices.push(tileData.y + tileData.height);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(v1);  // Flipped V
        
        // Bottom-right
        vertices.push(tileData.x + tileData.width);
        vertices.push(tileData.y);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(v2);  // Flipped V
        
        // Bottom-left
        vertices.push(tileData.x);
        vertices.push(tileData.y);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(v2);  // Flipped V
    }

    /**
     * Build vertex array from current tile data
     * Called every frame - no dirty tracking needed
     */
    // private function buildVertexArray():Void {
    //     vertices = [];
        
    //     var tileCount = 0;
        
    //     // Generate vertices for each tile in current data
    //     for (tileData in __currentTileData) {
    //         if (!tileData.visible) continue;
            
    //         // Generate vertices for this tile
    //         var tileVertices = generateTileVertices(tileData);
    //         for (vertex in tileVertices) {
    //             vertices.push(vertex);
    //         }
            
    //         tileCount++;
    //     }
        
    //     // Update render counts (indices are pre-generated, just set count)
    //     __verticesToRender = tileCount * 4;  // 4 vertices per tile
    //     __indicesToRender = tileCount * 6;   // 6 indices per tile (2 triangles)
    // }
    
    public function buildTile(tile:Tile):Void {
        
        generateTileVertices({
            x: tile.x + tile.offsetX,
            y: tile.y + tile.offsetY,
            width: tile.width,
            height: tile.height,
            regionId: tile.regionId,
            visible: tile.visible
        });        

        __verticesToRender += 4;
        __indicesToRender += 6;
    }

    /**
     * Update buffers - orphan and upload strategy
     * Called BEFORE render to update vertex data
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!active || atlasTexture == null) return;

        //__verticesToRender = 0;
        //__indicesToRender = 0;
        
        // Allocate buffer on first update only
        if (__bufferCapacity == 0) {
            __bufferCapacity = MAX_TILES;
            renderer.allocateTileBatchBuffers(this, MAX_TILES);
        }
        
        // Rebuild vertex array from visible tiles (every frame)
        //buildVertexArray();
        
        // Update vertices object for renderer
        //this.vertices = new Vertices(__vertexCache);
        
        // Orphan buffer before uploading (every frame)
        if (vbo != 0 && vertices.length > 0) {

            GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
            
            // Orphan old buffer storage
            var maxBufferSize = MAX_TILES * 4 * 5 * 4;
            untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
            
            // Now upload the actual data using standard method
            GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.STREAM_DRAW, vertices.length);
            
            GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        }
        
        needsBufferUpdate = false;
    }
    
    /**
     * Render the tile batch
     * Just sets uniforms - vertex data already updated in updateBuffers()
     */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible || !active || atlasTexture == null) {
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

    override public function postRender():Void {
        // Reset counts after rendering
        __verticesToRender = 0;
        __indicesToRender = 0;

        vertices = [];
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