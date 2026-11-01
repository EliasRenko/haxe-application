package gui;

class PropertySet {

    public var properties(default, null):Array<PropertyDefinition> = [];

    public function new() {}

    public function addString(name:String, getValue:Void->String, setValue:String->Void):Void {
        __add(name, PropertyKind.STRING, getValue, function(value) setValue(Std.string(value)));
    }

    public function addFloat(name:String, getValue:Void->Float, setValue:Float->Void):Void {
        __add(name, PropertyKind.FLOAT, getValue, function(value) setValue(cast value));
    }

    public function addInt(name:String, getValue:Void->Int, setValue:Int->Void):Void {
        __add(name, PropertyKind.INT, getValue, function(value) setValue(cast value));
    }

    public function addBool(name:String, getValue:Void->Bool, setValue:Bool->Void):Void {
        __add(name, PropertyKind.BOOL, getValue, function(value) setValue(cast value));
    }

    public function addEnum(name:String, getValue:Void->String, options:Array<String>,
            setValue:String->Void):Void {
        __add(name, PropertyKind.ENUM, getValue, function(value) setValue(Std.string(value)), options);
    }

    private function __add(name:String, kind:PropertyKind, getValue:Void->Dynamic,
            setValue:Dynamic->Void, ?options:Array<String>):Void {
        properties.push(new PropertyDefinition(name, kind, getValue, setValue, options));
    }
}
