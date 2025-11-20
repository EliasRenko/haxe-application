package display;

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