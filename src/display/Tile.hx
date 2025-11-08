package display;

class Tile {
    public var x:Float = 0.0;          // World X position
    public var y:Float = 0.0;          // World Y position
    public var width:Float = 1.0;      // Tile width in world units
    public var height:Float = 1.0;     // Tile height in world units
    public var regionId:Int = 0;       // Atlas region ID to use for UV coordinates
    public var parentBatch:TileBatch; // Reference to parent TileBatch

    public function new(parentBatch:TileBatch) {
        this.parentBatch = parentBatch;
    }
}