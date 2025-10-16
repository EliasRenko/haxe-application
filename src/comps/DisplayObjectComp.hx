package comps;

import Component;
import DisplayObject;

/**
 * Component that holds a DisplayObject for rendering
 * This allows entities to have visual representation without tight coupling
 */
class DisplayObjectComp extends Component {
    public var displayObject:DisplayObject;
    
    // Transform shortcuts (delegated to displayObject)
    public var x(get, set):Float;
    public var y(get, set):Float;
    public var z(get, set):Float;
    public var rotationX(get, set):Float;
    public var rotationY(get, set):Float;  
    public var rotationZ(get, set):Float;
    public var scaleX(get, set):Float;
    public var scaleY(get, set):Float;
    public var scaleZ(get, set):Float;
    public var visible(get, set):Bool;
    
    public function new(displayObject:DisplayObject) {
        super();
        this.displayObject = displayObject;
    }
    
    override public function cleanup():Void {
        if (displayObject != null) {
            // DisplayObject cleanup will be handled by the renderer
            displayObject = null;
        }
    }
    
    // Transform property getters/setters
    
    private function get_x():Float {
        return displayObject != null ? displayObject.x : 0.0;
    }
    
    private function set_x(value:Float):Float {
        if (displayObject != null) displayObject.x = value;
        return value;
    }
    
    private function get_y():Float {
        return displayObject != null ? displayObject.y : 0.0;
    }
    
    private function set_y(value:Float):Float {
        if (displayObject != null) displayObject.y = value;
        return value;
    }
    
    private function get_z():Float {
        return displayObject != null ? displayObject.z : 0.0;
    }
    
    private function set_z(value:Float):Float {
        if (displayObject != null) displayObject.z = value;
        return value;
    }
    
    private function get_rotationX():Float {
        return displayObject != null ? displayObject.rotationX : 0.0;
    }
    
    private function set_rotationX(value:Float):Float {
        if (displayObject != null) displayObject.rotationX = value;
        return value;
    }
    
    private function get_rotationY():Float {
        return displayObject != null ? displayObject.rotationY : 0.0;
    }
    
    private function set_rotationY(value:Float):Float {
        if (displayObject != null) displayObject.rotationY = value;
        return value;
    }
    
    private function get_rotationZ():Float {
        return displayObject != null ? displayObject.rotationZ : 0.0;
    }
    
    private function set_rotationZ(value:Float):Float {
        if (displayObject != null) displayObject.rotationZ = value;
        return value;
    }
    
    private function get_scaleX():Float {
        return displayObject != null ? displayObject.scaleX : 1.0;
    }
    
    private function set_scaleX(value:Float):Float {
        if (displayObject != null) displayObject.scaleX = value;
        return value;
    }
    
    private function get_scaleY():Float {
        return displayObject != null ? displayObject.scaleY : 1.0;
    }
    
    private function set_scaleY(value:Float):Float {
        if (displayObject != null) displayObject.scaleY = value;
        return value;
    }
    
    private function get_scaleZ():Float {
        return displayObject != null ? displayObject.scaleZ : 1.0;
    }
    
    private function set_scaleZ(value:Float):Float {
        if (displayObject != null) displayObject.scaleZ = value;
        return value;
    }
    
    private function get_visible():Bool {
        return displayObject != null ? displayObject.visible : true;
    }
    
    private function set_visible(value:Bool):Bool {
        if (displayObject != null) displayObject.visible = value;
        return value;
    }
}