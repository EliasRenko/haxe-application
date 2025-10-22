package gui;

/**
 * ThreeSlice - Manages 3 tiles for scalable UI elements (left, center, right)
 * Adapted for haxe-application's TileBatchFast system
 * 
 * Used for buttons and horizontal UI elements that need to scale
 * 
 * Layout:
 * [0: Left] [1: Center (stretches)] [2: Right]
 */
class ThreeSlice {
    
    /** Tile IDs in TileBatchFast */
    public var tileIds:Array<Int> = [];
    
    /** Reference to Canvas for TileBatchFast access */
    private var canvas:Canvas;
    
    /** Current position */
    private var x:Float = 0;
    private var y:Float = 0;
    
    /** Current size */
    private var width:Float = 48; // Default: 24 + 0 + 24
    private var height:Float = 24; // Default tile height
    
    /** Tile sizes */
    private var leftWidth:Float = 24;
    private var rightWidth:Float = 24;
    
    /**
     * Create a new three-slice
     * @param canvas Canvas reference for TileBatchFast access
     * @param leftWidth Width of left tile (default: 24)
     * @param rightWidth Width of right tile (default: 24)
     * @param height Height of all tiles (default: 24)
     */
    public function new(canvas:Canvas, ?leftWidth:Float = 24, ?rightWidth:Float = 24, ?height:Float = 24) {
        this.canvas = canvas;
        this.leftWidth = leftWidth;
        this.rightWidth = rightWidth;
        this.height = height;
        
        // Initialize with -1 (not yet created)
        tileIds = [-1, -1, -1];
    }
    
    /**
     * Initialize tiles in TileBatchFast
     * @param leftRegionId Region ID for left tile
     * @param centerRegionId Region ID for center tile
     * @param rightRegionId Region ID for right tile
     * @param x X position
     * @param y Y position
     * @param width Total width
     */
    public function init(leftRegionId:Int, centerRegionId:Int, rightRegionId:Int, x:Float, y:Float, width:Float):Void {
        this.x = x;
        this.y = y;
        this.width = width;
        
        // Calculate center width
        var centerWidth = width - leftWidth - rightWidth;
        
        // Add left tile
        tileIds[0] = canvas.tileBatchFast.addTile(x, y, leftWidth, height, leftRegionId);
        
        // Add center tile (stretches)
        tileIds[1] = canvas.tileBatchFast.addTile(x + leftWidth, y, centerWidth, height, centerRegionId);
        
        // Add right tile
        tileIds[2] = canvas.tileBatchFast.addTile(x + leftWidth + centerWidth, y, rightWidth, height, rightRegionId);
        
        trace("ThreeSlice: Initialized with tile IDs " + tileIds[0] + ", " + tileIds[1] + ", " + tileIds[2]);
    }
    
    /**
     * Update width - adjusts center tile and repositions right tile
     * @param newWidth New total width
     */
    public function setWidth(newWidth:Float):Void {
        this.width = newWidth;
        var centerWidth = newWidth - leftWidth - rightWidth;
        
        // Update center tile width
        if (tileIds[1] != -1) {
            var tile = canvas.tileBatchFast.tiles.get(tileIds[1]);
            if (tile != null) {
                canvas.tileBatchFast.updateTile(tileIds[1], x + leftWidth, y, centerWidth, height, tile.regionId);
            }
        }
        
        // Reposition right tile
        if (tileIds[2] != -1) {
            var tile = canvas.tileBatchFast.tiles.get(tileIds[2]);
            if (tile != null) {
                canvas.tileBatchFast.updateTile(tileIds[2], x + leftWidth + centerWidth, y, rightWidth, height, tile.regionId);
            }
        }
    }
    
    /**
     * Update X position - moves all tiles
     */
    public function setX(newX:Float):Void {
        this.x = newX;
        var centerWidth = width - leftWidth - rightWidth;
        
        // Update all tile positions
        for (i in 0...3) {
            if (tileIds[i] != -1) {
                var tile = canvas.tileBatchFast.tiles.get(tileIds[i]);
                if (tile != null) {
                    var tileX = x;
                    if (i == 1) tileX += leftWidth;
                    if (i == 2) tileX += leftWidth + centerWidth;
                    
                    canvas.tileBatchFast.updateTile(tileIds[i], tileX, y, tile.width, tile.height, tile.regionId);
                }
            }
        }
    }
    
    /**
     * Update Y position - moves all tiles
     */
    public function setY(newY:Float):Void {
        this.y = newY;
        
        // Update all tile Y positions
        for (i in 0...3) {
            if (tileIds[i] != -1) {
                var tile = canvas.tileBatchFast.tiles.get(tileIds[i]);
                if (tile != null) {
                    canvas.tileBatchFast.updateTile(tileIds[i], tile.x, newY, tile.width, tile.height, tile.regionId);
                }
            }
        }
    }
    
    /**
     * Update visibility of all tiles
     */
    public function setVisible(visible:Bool):Void {
        // TODO: Implement visibility when TileBatchFast supports per-tile visibility
        // For now, we'd need to remove/re-add tiles
    }
    
    /**
     * Change regions for all tiles (e.g., for hover state)
     */
    public function setRegions(leftRegionId:Int, centerRegionId:Int, rightRegionId:Int):Void {
        var regionIds = [leftRegionId, centerRegionId, rightRegionId];
        
        for (i in 0...3) {
            if (tileIds[i] != -1) {
                var tile = canvas.tileBatchFast.tiles.get(tileIds[i]);
                if (tile != null) {
                    canvas.tileBatchFast.updateTile(tileIds[i], tile.x, tile.y, tile.width, tile.height, regionIds[i]);
                }
            }
        }
    }
    
    /**
     * Release tiles from TileBatchFast
     */
    public function release():Void {
        for (tileId in tileIds) {
            if (tileId != -1) {
                canvas.tileBatchFast.removeTile(tileId);
            }
        }
        tileIds = [-1, -1, -1];
    }
}
