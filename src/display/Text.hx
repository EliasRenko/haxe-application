package display;

import ProgramInfo;

class Text extends TilemapFast {

    public function new(programInfo:ProgramInfo, mapWidth:Int, mapHeight:Int, tileSize:Float = 1.0) {
        super(programInfo, mapWidth, mapHeight, tileSize);
    }

    override public function render(cameraMatrix:math.Matrix):Void {
        super.render(cameraMatrix);
    }
}