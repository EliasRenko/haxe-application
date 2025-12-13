package;

import State;
import math.Matrix;
import utils.Rect;
import Component;

/**
 * Base class for game entities (game objects)
 * Entities are the building blocks of game states - anything that exists in the game world
 */
class Entity {
    
    // Entity properties
    public var active:Bool = true;
    public var visible:Bool = true;
    public var id:String;
    public var state:State = null; // Reference to parent state
    public var hitbox:Rect; // Collision hitbox
    
    // Component system
    private var components:Array<Component> = [];
    private var componentMap:Map<String, Component> = new Map();
    
    // Private entity counter for auto-generating IDs
    private static var __nextId:Int = 0;
    
    public function new(id:String = null) {
        this.id = id != null ? id : "entity_" + (__nextId++);
        trace("Created entity '" + this.id + "'");
    }
    
    /**
     * Add a component to this entity
     */
    public function addComponent<T:Component>(component:T):T {
        var className = Type.getClassName(Type.getClass(component));
        
        if (componentMap.exists(className)) {
            trace("Warning: Entity '" + id + "' already has component " + className);
            return cast componentMap.get(className);
        }
        
        components.push(component);
        componentMap.set(className, component);
        component.onAdded(this);
        
        trace("Added component " + className + " to entity '" + id + "'");
        return component;
    }
    
    /**
     * Remove a component from this entity
     */
    public function removeComponent<T:Component>(componentClass:Class<T>):Bool {
        var className = Type.getClassName(componentClass);
        var component = componentMap.get(className);
        
        if (component == null) {
            return false;
        }
        
        components.remove(component);
        componentMap.remove(className);
        component.onRemoved();
        component.cleanup();
        
        trace("Removed component " + className + " from entity '" + id + "'");
        return true;
    }
    
    /**
     * Get a component by its class type
     */
    public function getComponent<T:Component>(componentClass:Class<T>):T {
        var className = Type.getClassName(componentClass);
        return cast componentMap.get(className);
    }
    
    /**
     * Check if entity has a specific component
     */
    public function hasComponent<T:Component>(componentClass:Class<T>):Bool {
        var className = Type.getClassName(componentClass);
        return componentMap.exists(className);
    }
    
    /**
     * Get all components of this entity
     */
    public function getComponents():Array<Component> {
        return components.copy();
    }
    
    /**
     * Called every frame to update entity logic
     * Override in subclasses for entity-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;
        
        // Update all components
        for (component in components) {
            if (component.enabled) {
                component.update(deltaTime);
            }
        }
    }
    
    /**
     * Called after all updates for late processing
     */
    public function lateUpdate(deltaTime:Float):Void {
        if (!active) return;
        
        // Late update all components
        for (component in components) {
            if (component.enabled) {
                component.lateUpdate(deltaTime);
            }
        }
    }
    
    /**
     * Called every frame to render this entity
     * Now accepts the view-projection matrix from the State's camera
     */
    public function render(renderer:Renderer, viewProjectionMatrix:math.Matrix):Void {
        if (!active || !visible) {
            return;
        }
        
        // Override in subclasses to implement custom rendering
    }
    
    /**
     * Clean up entity resources
     */
    public function cleanup(renderer:Renderer):Void {

        // Clean up all components
        for (component in components) {
            component.cleanup();
        }
        components = [];
        componentMap.clear();
        
        // Remove from state if attached
        if (state != null) {
            state.removeEntity(this);
        }
        
        trace("Entity '" + id + "' cleaned up");
    }
    
    /**
     * Get debug info about this entity
     */
    public function getDebugInfo():String {
        var componentInfo = components.length > 0 ? ', Components: ${components.length}' : '';
        return 'Entity "${id}" - Active: ${active}, Visible: ${visible}${componentInfo}';
    }
}