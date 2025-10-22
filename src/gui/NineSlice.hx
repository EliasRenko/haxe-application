package gui;

/**
 * NineSlice - Manages 9 tiles for scalable panels and windows
 * Adapted for haxe-application's TileBatchFast system
 * 
 * Used for panels, windows, and other UI elements that need to scale in both dimensions
 * 
 * Layout:
 * [0: TL] [1: Top  (stretch-x)] [2: TR]
 * [3: Left (stretch-y)] [4: Center (stretch-x,y)] [5: Right (stretch-y)]
 * [6: BL] [7: Bottom (stretch-x)] [8: BR]
 */
class NineSlice {
    
    /** Tile IDs in TileBatchFast */
    public var tileIds:Array<Int> = [];
    
    /** Reference to Canvas for TileBatchFast access */
    private var canvas:Canvas;
    
    /** Current position */
    private var x:Float = 0;
    private var y:Float = 0;
    
    /** Current size */
    private var width:Float = 72;  // Default: 24 + 24 + 24
    private var height:Float = 72; // Default: 24 + 24 + 24
    
    /** Corner/edge sizes */
    private var cornerSize:Float = 24;
    
    /**
     * Create a new nine-slice
     * @param canvas Canvas reference for TileBatchFast access
     * @param cornerSize Size of corner tiles (default: 24)
     */
    public function new(canvas:Canvas, ?cornerSize:Float = 24) {
        this.canvas = canvas;
        this.cornerSize = cornerSize;
        
        // Initialize with -1 (not yet created)
        tileIds = [-1, -1, -1, -1, -1, -1, -1, -1, -1];
    }
    
    /**
     * Initialize tiles in TileBatchFast
     * @param regionIds Array of 9 region IDs [TL, T, TR, L, C, R, BL, B, BR]
     * @param x X position
     * @param y Y position
     * @param width Total width
     * @param height Total height
     */
    public function init(regionIds:Array<Int>, x:Float, y:Float, width:Float, height:Float):Void {
        if (regionIds.length != 9) {
            trace("NineSlice: Error - Need 9 region IDs");
            return;
        }
        
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        
        var cs = cornerSize;
        var innerWidth = width - (cs * 2);
        var innerHeight = height - (cs * 2);
        
        // Row 0 (top)
        tileIds[0] = canvas.tileBatchFast.addTile(x, y, cs, cs, regionIds[0]); // TL
        tileIds[1] = canvas.tileBatchFast.addTile(x + cs, y, innerWidth, cs, regionIds[1]); // Top
        tileIds[2] = canvas.tileBatchFast.addTile(x + cs + innerWidth, y, cs, cs, regionIds[2]); // TR
        
        // Row 1 (middle)
        tileIds[3] = canvas.tileBatchFast.addTile(x, y + cs, cs, innerHeight, regionIds[3]); // Left
        tileIds[4] = canvas.tileBatchFast.addTile(x + cs, y + cs, innerWidth, innerHeight, regionIds[4]); // Center
        tileIds[5] = canvas.tileBatchFast.addTile(x + cs + innerWidth, y + cs, cs, innerHeight, regionIds[5]); // Right
        
        // Row 2 (bottom)
        tileIds[6] = canvas.tileBatchFast.addTile(x, y + cs + innerHeight, cs, cs, regionIds[6]); // BL
        tileIds[7] = canvas.tileBatchFast.addTile(x + cs, y + cs + innerHeight, innerWidth, cs, regionIds[7]); // Bottom
        tileIds[8] = canvas.tileBatchFast.addTile(x + cs + innerWidth, y + cs + innerHeight, cs, cs, regionIds[8]); // BR
        
        trace("NineSlice: Initialized with 9 tiles at (" + x + "," + y + ") size=" + width + "x" + height);
    }
    
    /**
     * Update width - adjusts stretching tiles
     */
    public function setWidth(newWidth:Float):Void {
        this.width = newWidth;
        updateLayout();
    }
    
    /**
     * Update height - adjusts stretching tiles
     */
    public function setHeight(newHeight:Float):Void {
        this.height = newHeight;
        updateLayout();
    }
    
    /**
     * Update both width and height
     */
    public function setSize(newWidth:Float, newHeight:Float):Void {
        this.width = newWidth;
        this.height = newHeight;
        updateLayout();
    }
    
    /**
     * Update X position - moves all tiles
     */
    public function setX(newX:Float):Void {
        this.x = newX;
        updateLayout();
    }
    
    /**
     * Update Y position - moves all tiles
     */
    public function setY(newY:Float):Void {
        this.y = newY;
        updateLayout();
    }
    
    /**
     * Update position and size
     */
    public function setBounds(newX:Float, newY:Float, newWidth:Float, newHeight:Float):Void {
        this.x = newX;
        this.y = newY;
        this.width = newWidth;
        this.height = newHeight;
        updateLayout();
    }
    
    /**
     * Internal method to update all tile positions and sizes
     */
    private function updateLayout():Void {
        var cs = cornerSize;
        var innerWidth = width - (cs * 2);
        var innerHeight = height - (cs * 2);
        
        // Define layout for all 9 tiles [x, y, width, height]
        var layouts = [
            // Row 0 (top)
            [x, y, cs, cs],                                    // 0: TL
            [x + cs, y, innerWidth, cs],                       // 1: Top
            [x + cs + innerWidth, y, cs, cs],                  // 2: TR
            
            // Row 1 (middle)
            [x, y + cs, cs, innerHeight],                      // 3: Left
            [x + cs, y + cs, innerWidth, innerHeight],         // 4: Center
            [x + cs + innerWidth, y + cs, cs, innerHeight],    // 5: Right
            
            // Row 2 (bottom)
            [x, y + cs + innerHeight, cs, cs],                 // 6: BL
            [x + cs, y + cs + innerHeight, innerWidth, cs],    // 7: Bottom
            [x + cs + innerWidth, y + cs + innerHeight, cs, cs] // 8: BR
        ];
        
        // Update all tiles
        for (i in 0...9) {
            if (tileIds[i] != -1) {
                var tile = canvas.tileBatchFast.tiles.get(tileIds[i]);
                if (tile != null) {
                    var layout = layouts[i];
                    canvas.tileBatchFast.updateTile(
                        tileIds[i],
                        layout[0], // x
                        layout[1], // y
                        layout[2], // width
                        layout[3], // height
                        tile.regionId
                    );
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
     * Change regions for all tiles (e.g., for different panel style)
     */
    public function setRegions(regionIds:Array<Int>):Void {
        if (regionIds.length != 9) {
            trace("NineSlice: Error - Need 9 region IDs");
            return;
        }
        
        for (i in 0...9) {
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
        tileIds = [-1, -1, -1, -1, -1, -1, -1, -1, -1];
    }
}
