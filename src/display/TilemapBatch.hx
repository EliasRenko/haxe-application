package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import Texture;
import math.Matrix;

/**
 * TilemapBatch - Grid-based tilemap using TileBatch for efficient rendering
 *
 * Combines the grid-based tile management of Tilemap with the primitive
 * batching capabilities of TileBatch for optimal performance.
 *
 * Features:
 * - Grid-based tile placement with mapWidth/mapHeight
 * - Texture atlas support with automatic UV calculation
 * - Dynamic tile updates with efficient buffer management
 * - Same API as Tilemap but with TileBatch performance benefits
 */
class TilemapBatch extends TileBatch {

    // Grid properties
    public var mapWidth:Int = 0;           // Width in tiles
    public var mapHeight:Int = 0;          // Height in tiles
    public var tileSize:Int = 16;          // Size of each tile in pixels/world units

    // Tile data - 2D array of tile IDs (0 = empty)
    public var tileData:Array<Array<Int>> = [];

    // Dirty tracking for efficient updates
    private var __entireMapDirty:Bool = true;
    private var __dirtyTiles:Array<{x:Int, y:Int}> = [];

    // Tile-to-region mapping (tileId -> regionId)
    private var __tileToRegion:Map<Int, Int> = new Map();

    /**
     * Create a new TilemapBatch
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     * @param mapWidth Width of the tilemap in tiles
     * @param mapHeight Height of the tilemap in tiles
     * @param tileSize Size of each tile in pixels
     */
    public function new(programInfo:ProgramInfo, texture:Texture, mapWidth:Int = 0, mapHeight:Int = 0, tileSize:Int = 16) {
        super(programInfo, texture);

        this.mapWidth = mapWidth;
        this.mapHeight = mapHeight;
        this.tileSize = tileSize;

        // Initialize empty tile data
        initializeTileData();
    }

    /**
     * Initialize the tile data array
     */
    private function initializeTileData():Void {
        tileData = [];
        for (y in 0...mapHeight) {
            tileData[y] = [];
            for (x in 0...mapWidth) {
                tileData[y][x] = 0; // 0 = empty tile
            }
        }
        __entireMapDirty = true;
    }

    /**
     * Configure the texture atlas regions
     * @param atlasData Array of {id:Int, x:Int, y:Int, width:Int, height:Int} objects
     */
    public function setAtlas(atlasData:Array<{id:Int, x:Int, y:Int, width:Int, height:Int}>):Void {
        // Clear existing regions
        atlasRegions.clear();
        __tileToRegion.clear();

        // Define regions for each atlas entry
        for (entry in atlasData) {
            var regionId = defineRegion(entry.x, entry.y, entry.width, entry.height);
            __tileToRegion.set(entry.id, regionId);
            trace("TilemapBatch: Defined atlas region for tile " + entry.id + " -> region " + regionId);
        }

        __entireMapDirty = true;
        if (active) {
            needsBufferUpdate = true;
        }
    }

    /**
     * Set a tile at the specified grid position
     * @param x Grid X coordinate
     * @param y Grid Y coordinate
     * @param tileId Tile ID (0 = empty)
     */
    public function setTile(x:Int, y:Int, tileId:Int):Void {
        if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
            trace("TilemapBatch: Warning - Tile position (" + x + "," + y + ") is out of bounds");
            return;
        }

        if (tileData[y][x] != tileId) {
            tileData[y][x] = tileId;
            __dirtyTiles.push({x: x, y: y});
            __entireMapDirty = true; // For now, mark entire map dirty

            if (active) {
                needsBufferUpdate = true;
            }
        }
    }

    /**
     * Get the tile ID at the specified grid position
     * @param x Grid X coordinate
     * @param y Grid Y coordinate
     * @return Tile ID (0 = empty)
     */
    public function getTileId(x:Int, y:Int):Int {
        if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
            return 0;
        }
        return tileData[y][x];
    }

    /**
     * Generate the tile batch from the tile data grid
     * Converts grid-based tile data into TileBatch tiles
     */
    private function generateBatch():Void {
        // Clear existing tiles
        clear();

        // Add tiles for each non-empty grid position
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                var tileId = tileData[y][x];
                if (tileId != 0) { // Skip empty tiles
                    var regionId = __tileToRegion.get(tileId);
                    if (regionId != null) {
                        // Convert grid coordinates to world coordinates
                        var worldX = x * tileSize;
                        var worldY = y * tileSize;

                        // Add tile to batch
                        addTile(worldX, worldY, tileSize, tileSize, regionId);

                        // Debug first few tiles
                        if (x < 3 && y < 3) {
                            trace("TilemapBatch: Added tile (" + x + "," + y + ") ID=" + tileId + " at world(" + worldX + "," + worldY + ") using region " + regionId);
                        }
                    } else {
                        trace("TilemapBatch: Warning - No atlas region defined for tile ID " + tileId);
                    }
                }
            }
        }

        __entireMapDirty = false;
        __dirtyTiles = [];
    }

    /**
     * Override updateBuffers to regenerate the tile batch when needed
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!active || atlasTexture == null) return;

        // If map is dirty, regenerate the entire batch
        if (__entireMapDirty) {
            generateBatch();
        }

        // Call parent updateBuffers to handle the actual buffer upload
        super.updateBuffers(renderer);
    }

    /**
     * Fill an area of the tilemap with a specific tile
     * @param startX Starting X coordinate
     * @param startY Starting Y coordinate
     * @param width Width in tiles
     * @param height Height in tiles
     * @param tileId Tile ID to fill with
     */
    public function fillArea(startX:Int, startY:Int, width:Int, height:Int, tileId:Int):Void {
        for (y in startY...(startY + height)) {
            for (x in startX...(startX + width)) {
                setTile(x, y, tileId);
            }
        }
        trace("TilemapBatch: Filled area (" + startX + ", " + startY + ") " + width + "x" + height + " with tile " + tileId);
    }

    /**
     * Clear the entire tilemap (set all tiles to 0)
     */
    override public function clear():Void {
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                tileData[y][x] = 0;
            }
        }
        __entireMapDirty = true;
        if (active) {
            needsBufferUpdate = true;
        }
        // Call parent clear to clear the tile batch
        super.clear();
        trace("TilemapBatch: Cleared tilemap");
    }

    /**
     * Get tilemap dimensions
     * @return {width: Int, height: Int} Map size in tiles
     */
    public function getMapSize():{width:Int, height:Int} {
        return {width: mapWidth, height: mapHeight};
    }

    /**
     * Convert world coordinates to tile coordinates
     * @param worldX World X coordinate
     * @param worldY World Y coordinate
     * @return {x: Int, y: Int} Tile coordinates (may be out of bounds)
     */
    public function worldToTile(worldX:Float, worldY:Float):{x:Int, y:Int} {
        return {
            x: Std.int(worldX / tileSize),
            y: Std.int(worldY / tileSize)
        };
    }

    /**
     * Convert tile coordinates to world coordinates (center of tile)
     * @param tileX Tile X coordinate
     * @param tileY Tile Y coordinate
     * @return {x: Float, y: Float} World coordinates
     */
    public function tileToWorld(tileX:Int, tileY:Int):{x:Float, y:Float} {
        return {
            x: tileX * tileSize + tileSize * 0.5,
            y: tileY * tileSize + tileSize * 0.5
        };
    }

    /**
     * Resize the tilemap
     * @param newWidth New width in tiles
     * @param newHeight New height in tiles
     */
    public function resize(newWidth:Int, newHeight:Int):Void {
        if (newWidth == mapWidth && newHeight == mapHeight) return;

        var oldData = tileData.copy();

        mapWidth = newWidth;
        mapHeight = newHeight;

        // Reinitialize tile data
        initializeTileData();

        // Copy old data (clipped to new size)
        var copyWidth = Std.int(Math.min(newWidth, oldData[0].length));
        var copyHeight = Std.int(Math.min(newHeight, oldData.length));

        for (y in 0...copyHeight) {
            for (x in 0...copyWidth) {
                tileData[y][x] = oldData[y][x];
            }
        }

        __entireMapDirty = true;
        if (active) {
            needsBufferUpdate = true;
        }

        trace("TilemapBatch: Resized to " + newWidth + "x" + newHeight + " tiles");
    }
}