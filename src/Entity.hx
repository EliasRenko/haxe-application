package;

import State;
import math.Matrix;
import utils.Rect;

class Entity {
    
    // Entity properties
    public var active:Bool = true;
    public var angle:Float = 0.0;
    public var visible:Bool = true;
    public var id:String;
    public var state:State = null; // Reference to parent state
    public var hitbox:Rect; // Collision hitbox
    
    // Private entity counter for auto-generating IDs
    private static var __nextId:Int = 0;
    
    public function new(id:String = null) {
        this.id = id != null ? id : "entity_" + (__nextId++);
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
     * Now accepts the view-projection matrix from the State's camera
     */
    public function render(renderer:Renderer, viewProjectionMatrix:math.Matrix):Void {
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