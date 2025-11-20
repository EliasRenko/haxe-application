package display;

/**
 * TileStreaming - Lightweight tile for TileBatchStreaming
 * 
 * Designed for high-performance streaming scenarios where tiles update frequently.
 * Minimal memory footprint - no parent reference needed since batch handles everything.
 */
class TileStreaming {
    public var x:Float = 0.0;          // World X position
    public var y:Float = 0.0;          // World Y position
    public var width:Float = 1.0;      // Tile width in world units
    public var height:Float = 1.0;     // Tile height in world units
    public var regionId:Int = 0;       // Atlas region ID to use for UV coordinates
    public var visible:Bool = true;    // Visibility flag
    public var offsetX:Float = 0.0;    // Offset X position
    public var offsetY:Float = 0.0;    // Offset Y position
    
    public function new(regionId:Int = 0) {
        this.regionId = regionId;
    }
}
