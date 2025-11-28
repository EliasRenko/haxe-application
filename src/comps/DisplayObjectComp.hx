package comps;

import Component;
import DisplayObject;

/**
 * Component that holds a DisplayObject for rendering
 * DEPRECATED: Use TransformComponent + RenderComponent with Cog ECS instead
 * This legacy component is kept for backward compatibility with old states
 */
class DisplayObjectComp extends Component {
    
    public var displayObject:DisplayObject;
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
    
    private function get_visible():Bool {
        return displayObject != null ? displayObject.visible : true;
    }
    
    private function set_visible(value:Bool):Bool {
        if (displayObject != null) displayObject.visible = value;
        return value;
    }
}