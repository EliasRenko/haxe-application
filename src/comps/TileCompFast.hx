package comps;

import Component;
import display.TileBatchFast;

/**
 * Component that represents a tile within a TileBatchFast
 * Provides an interface to modify the tile without direct DisplayObject access
 * Optimized for TileBatchFast's dynamic update API
 */
class TileCompFast extends Component {
    public var tileBatch:TileBatchFast;
    public var tileId:Int;
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    
    public function new(tileBatch:TileBatchFast, tileId:Int, x:Float, y:Float, width:Float, height:Float) {
        super();
        this.tileBatch = tileBatch;
        this.tileId = tileId;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }
    
    /**
     * Update tile position in the batch using TileBatchFast's updateTile API
     */
    public function setPosition(x:Float, y:Float):Void {
        this.x = x;
        this.y = y;
        tileBatch.updateTile(tileId, x, y, null, null, null);
        
        // Update entity hitbox if it exists
        if (entity != null && entity.hitbox != null) {
            entity.hitbox.x = x + tileBatch.x;
            entity.hitbox.y = y + tileBatch.y;
        }
    }
    
    /**
     * Change tile appearance using TileBatchFast's updateTile API
     */
    public function setRegion(regionId:Int):Void {
        tileBatch.updateTile(tileId, null, null, null, null, regionId);
    }
    
    /**
     * Update tile size
     */
    public function setSize(width:Float, height:Float):Void {
        this.width = width;
        this.height = height;
        tileBatch.updateTile(tileId, null, null, width, height, null);
        
        // Update entity hitbox if it exists
        if (entity != null && entity.hitbox != null) {
            entity.hitbox.width = width;
            entity.hitbox.height = height;
        }
    }
    
    /**
     * Update all tile properties at once (more efficient than multiple calls)
     */
    public function setAll(x:Float, y:Float, width:Float, height:Float, regionId:Int):Void {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        tileBatch.updateTile(tileId, x, y, width, height, regionId);
        
        // Update entity hitbox if it exists
        if (entity != null && entity.hitbox != null) {
            entity.hitbox.x = x + tileBatch.x;
            entity.hitbox.y = y + tileBatch.y;
            entity.hitbox.width = width;
            entity.hitbox.height = height;
        }
    }
    
    /**
     * Sync position from entity if other components moved it
     */
    override public function lateUpdate(deltaTime:Float):Void {
        // If entity has a DisplayObjectComponent, sync from it
        var displayComp = entity.getComponent(DisplayObjectComp);
        if (displayComp != null) {
            if (displayComp.x != x || displayComp.y != y) {
                setPosition(displayComp.x, displayComp.y);
            }
        }
    }
    
    /**
     * Remove tile from batch when component is removed
     */
    override public function onRemoved():Void {
        if (tileBatch != null && tileBatch.hasTile(tileId)) {
            tileBatch.removeTile(tileId);
        }
    }
}
