package comps;

import Component;
import display.TileBatch;

/**
 * Component that represents a tile within a TileBatch
 * Provides an interface to modify the tile without direct DisplayObject access
 */
class TileComp extends Component {
    public var tileBatch:TileBatch;
    public var tileId:Int;
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    
    public function new(tileBatch:TileBatch, tileId:Int, x:Float, y:Float, width:Float, height:Float) {
        super();
        this.tileBatch = tileBatch;
        this.tileId = tileId;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }
    
    /**
     * Update tile position in the batch
     */
    public function setPosition(x:Float, y:Float):Void {
        this.x = x;
        this.y = y;
        tileBatch.updateTilePosition(tileId, x, y);
        
        // Update entity hitbox if it exists
        if (entity != null && entity.hitbox != null) {
            entity.hitbox.x = x;
            entity.hitbox.y = y;
        }
    }
    
    /**
     * Change tile appearance
     */
    public function setRegion(regionId:Int):Void {
        //tileBatch.updateTileRegion(tileId, regionId);
    }
    
    /**
     * Sync position from entity if other components moved it
     */
    override public function lateUpdate(deltaTime:Float):Void {
        // Position managed by other components (e.g. VelocityComp)
    }
}