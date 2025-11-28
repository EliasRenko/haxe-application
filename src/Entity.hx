package;

import State;
import math.Matrix;
import utils.Rect;
import Component;
import comps.DisplayObjectComp;
import cog.Components;

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
    
    // Cog Components for ECS integration
    public var components:Components;
    
    // Legacy component system (deprecated - use Cog components instead)
    private var __components:Array<Component> = [];
    private var componentMap:Map<String, Component> = new Map();
    
    // Private entity counter for auto-generating IDs
    private static var __nextId:Int = 0;
    
    public function new(id:String = null) {
        this.id = id != null ? id : "entity_" + (__nextId++);
        this.components = new Components();
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
        
        __components.push(component);
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
        
        __components.remove(component);
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
        return __components.copy();
    }
    
    /**
     * Called every frame to update entity logic
     * Override in subclasses for entity-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;
        
        // Update all components
        for (component in __components) {
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
        for (component in __components) {
            if (component.enabled) {
                component.lateUpdate(deltaTime);
            }
        }
    }
    
    /**
     * Called every frame to render this entity
     * Now accepts the view-projection matrix from the State's camera
     */
    public function render(renderer:Dynamic, viewProjectionMatrix:math.Matrix):Void {
        if (!active || !visible) {
            return;
        }
        
        // Get DisplayObjectComponent if it exists
        var displayComp = getComponent(DisplayObjectComp);
        if (displayComp != null && displayComp.displayObject != null && displayComp.visible) {
            renderer.renderDisplayObject(displayComp.displayObject, viewProjectionMatrix);
        }
    }
    
    /**
     * Clean up entity resources
     */
    public function cleanup(renderer:Renderer):Void {

        // TODO: Workaround to release DisplayObject from DisplayObjectComp
        var displayComp = getComponent(DisplayObjectComp);
        if (displayComp != null && displayComp.displayObject != null) {
            displayComp.displayObject.release(renderer);
        }

        // Clean up all components
        for (component in __components) {
            component.cleanup();
        }
        __components = [];
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
        var displayComp = getComponent(DisplayObjectComp);
        var pos = displayComp != null ? '(has display)' : '(no display)';
        var componentInfo = __components.length > 0 ? ', Components: ${__components.length}' : '';
        return 'Entity "${id}" at ${pos} - Active: ${active}, Visible: ${visible}${componentInfo}';
    }
}