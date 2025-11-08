package gui;

import display.Tile;
import haxe.ds.Vector;

@:forward(get)
abstract ThreeSlice(Vector<Tile>) from Vector<Tile> to Vector<Tile> {

    public function new() {

        this = new Vector<Tile>(3);

        for (i in 0...3) {

            this.set(i, new Tile());
        }

        this.get(1).offsetX = 24;
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
        
        this.get(1).width = value - 48;
		
		this.get(2).offsetX = value - 24;
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