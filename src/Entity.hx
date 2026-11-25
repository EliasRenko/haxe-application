package;

import State;
import utils.Rect;

class Entity {
    // Statics
    private static var NEXT_ID:Int = 0;

    // Publics
    public var active:Bool = true;
    public var id:String;
    public var state:State = null; // Reference to parent state
    public var visible:Bool = true;
    
    public function new(id:String = null) {
        this.id = id != null ? id : "entity_" + (NEXT_ID++);
    }
    
    /**
     * Called every frame to update entity logic
     * Override in subclasses for entity-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;
    }
    
    /**
     * Called after all updates for late processing
     */
    public function lateUpdate(deltaTime:Float):Void {
        if (!active) return;
    }
    
    /**
     * Called every frame to render this entity
     */
    public function render(renderer:Renderer):Void {
        if (!active || !visible) {
            return;
        }
    }
    
    /**
     * Clean up entity resources
     */
    public function cleanup(renderer:Renderer):Void {
        if (state != null) {
            state.removeEntity(this);
        }
    }
}