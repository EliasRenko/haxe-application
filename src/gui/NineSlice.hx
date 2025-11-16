package gui;

import display.Tile;
import haxe.ds.Vector;

@:forward(get)
abstract NineSlice(Vector<Tile>) from Vector<Tile> to Vector<Tile> {
    
    public static inline var DEFAULT_TILE_WIDTH:Int = 28;
    public static inline var DEFAULT_TILE_HEIGHT:Int = 28;

    public function new() {
        this = new Vector<Tile>(9);

        for (i in 0...9) {
            var tile = new Tile(null);
            tile.width = DEFAULT_TILE_WIDTH;
            tile.height = DEFAULT_TILE_HEIGHT;

            this.set(i, tile);
        }

        this.get(1).offsetX = DEFAULT_TILE_WIDTH;
		this.get(3).offsetY = DEFAULT_TILE_HEIGHT;
		this.get(4).offsetX = DEFAULT_TILE_WIDTH;
		this.get(4).offsetY = DEFAULT_TILE_HEIGHT;
		this.get(5).offsetY = DEFAULT_TILE_HEIGHT;
        this.get(7).offsetX = DEFAULT_TILE_WIDTH;
    }

    public function iterate(func:(Tile)->Void):Void {
        for (tile in this) {
            func(tile);
        }
    }

    public function setHeight(value:Float):Void {
        this.get(3).height = value - (DEFAULT_TILE_HEIGHT * 2);
		this.get(4).height = value - (DEFAULT_TILE_HEIGHT * 2);
		this.get(5).height = value - (DEFAULT_TILE_HEIGHT * 2);
		this.get(6).offsetY = value - DEFAULT_TILE_HEIGHT;
		this.get(7).offsetY = value - DEFAULT_TILE_HEIGHT;
        this.get(8).offsetY = value - DEFAULT_TILE_HEIGHT;
    }

    public function setVisible(value:Bool):Void {
        for (tile in this) {
            tile.visible = value;
        }
    }

    public function setWidth(value:Float):Void {
        this.get(1).width = value - (DEFAULT_TILE_WIDTH * 2);
		this.get(2).offsetX = value - DEFAULT_TILE_WIDTH;
		this.get(4).width = value - (DEFAULT_TILE_WIDTH * 2);
		this.get(5).offsetX = value - DEFAULT_TILE_WIDTH;
		this.get(7).width = value - (DEFAULT_TILE_WIDTH * 2);
		this.get(8).offsetX = value - DEFAULT_TILE_WIDTH;
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