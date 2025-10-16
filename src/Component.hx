package;

/**
 * Base class for all components
 * Components add specific functionality to entities
 */
class Component {
    public var entity:Entity;
    public var enabled:Bool = true;
    
    public function new() {
        // Components start enabled by default
    }
    
    /**
     * Called when component is added to an entity
     */
    public function onAdded(entity:Entity):Void {
        this.entity = entity;
    }
    
    /**
     * Called when component is removed from an entity
     */
    public function onRemoved():Void {
        this.entity = null;
    }
    
    /**
     * Called every frame to update component logic
     */
    public function update(deltaTime:Float):Void {
        // Override in subclasses
    }
    
    /**
     * Called after all updates for late processing
     */
    public function lateUpdate(deltaTime:Float):Void {
        // Override in subclasses if needed
    }
    
    /**
     * Clean up component resources
     */
    public function cleanup():Void {
        // Override in subclasses if needed
    }
}