package impl;

interface IRuntime {
    
    public var active(get, null):Bool;
    public var vsync(get, set):Int;

    public function init():Bool;
    public function release():Void;
    public function run():Void;
}