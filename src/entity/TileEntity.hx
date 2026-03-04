package entity;

import Entity;
import display.ManagedTileBatch;
import display.Tile;

/**
 * TileEntity - An entity that owns a single tile inside a ManagedTileBatch.
 *
 * Instead of attaching a TileComp to a plain Entity, subclass TileEntity
 * directly.  The tile coordinates, size and batch reference live here, no
 * component system required.
 *
 * Subclasses get position + size for free and can call setPosition() /
 * setRegion() to drive the visual tile.
 */
class TileEntity extends Entity {

    public var tile:Tile = null;

    public function new(?id:String) {
        super(id);
    }

    /**
     * Bind this entity to a tile that was already added to a batch.
     * Called by the map loader immediately after construction.
     */
    public function bindTile(batch:ManagedTileBatch, tileId:Int):Void {
        this.tile = batch.getTile(tileId);
    }

    /**
     * Move the entity and update its tile position.
     */
    public function setPosition(x:Float, y:Float):Void {
        if (tile != null) {
            tile.x = x;
            tile.y = y;
        }
    }

    /**
     * Rotate the tile (degrees, around its centre).
     */
    public function setRotation(degrees:Float):Void {
        if (tile != null) tile.rotation = degrees;
    }

    /**
     * Swap the tile's atlas region.
     */
    public function setRegion(regionId:Int):Void {
        if (tile != null) tile.regionId = regionId;
    }
}
