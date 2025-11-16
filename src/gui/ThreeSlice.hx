package gui;

import display.Tile;
import haxe.ds.Vector;

@:forward(get)
abstract ThreeSlice(Vector<Tile>) from Vector<Tile> to Vector<Tile> {

    public static inline var DEFAULT_TILE_WIDTH:Int = 28;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 28;

    public function new() {

        this = new Vector<Tile>(3);

        for (i in 0...3) {

            var tile = new Tile(null);
            tile.width = DEFAULT_TILE_WIDTH;
            tile.height = DEFAULT_TILE_HEIGHT;

            this.set(i, tile);
        }

        this.get(1).offsetX = DEFAULT_TILE_WIDTH;
    }

    public function iterate(func:(Tile)->Void):Void {
        
        for (tile in this) {

            func(tile);
        }
    }

    public function setVisible(value:Bool):Void {
        
        for (tile in this) {

            tile.visible = value;
        }
    }

    public function setWidth(value:Float):Void {
        
        this.get(1).width = value - (2 * DEFAULT_TILE_WIDTH);
		
		this.get(2).offsetX = value - DEFAULT_TILE_WIDTH;
    }

    public function setX(value:Float):Void {
        
        for (tile in this) {

            tile.x = value;
        }
    }

    public function setY(value:Float):Void {
        
        for (tile in this) {

            tile.y = value;
        }
    }
}