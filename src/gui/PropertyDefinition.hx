package gui;

class PropertyDefinition {

    public var name(default, null):String;
    public var kind(default, null):PropertyKind;
    public var options(default, null):Array<String>;

    private var _getValue:Void->Dynamic;
    private var _setValue:Dynamic->Void;

    public function new(name:String, kind:PropertyKind, getValue:Void->Dynamic,
            setValue:Dynamic->Void, ?options:Array<String>) {
        this.name = name;
        this.kind = kind;
        this.options = options != null ? options : [];
        _getValue = getValue;
        _setValue = setValue;
    }

    public function getValue():Dynamic {
        return _getValue();
    }

    public function setValue(value:Dynamic):Void {
        _setValue(value);
    }
}
