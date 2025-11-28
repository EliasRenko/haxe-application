package;

import comps.DisplayObjectComp;
import comps.RenderComponent;
import Entity;
import Camera;
import App;
import cog.Engine;
import cog.System;
import cog.systems.RenderSystem;

/**
 * Base class for game states (worlds/scenes/levels)
 * States manage collections of entities and handle state-specific logic
 */
class State {
    // State properties
    public var active:Bool = true;
    public var app(get, null):App;
    public var camera:Camera;
    public var entities:Array<Entity> = [];
    public var name:String;
    public var id:Int;

    // ECS system lists
    public var updateSystems:Array<System> = [];
    public var renderSystems:Array<System> = [];

    // Cog ECS engine for this state (for update systems only)
    public var engine:Engine;
    public var renderSystem:RenderSystem;

    // Privates
    private var __app:App;
    private static var __nextId:Int = 0;
    
    public function new(name:String, app:App) {
        this.name = name;
        this.id = __nextId++;
        this.entities = [];
        this.__app = app;
        
        // Initialize camera for this state
        this.camera = new Camera();
        // Set reasonable defaults for 3D perspective
        camera.ortho = false;
        camera.x = 0.0;
        camera.y = 0.0;
        camera.z = 3.0; // Move camera back to see objects
        camera.pitch = 0.0;
        camera.yaw = 0.0;
        camera.roll = 0.0;
        
        // Initialize Cog ECS engine (for update systems only)
        engine = new Engine();

        // Create RenderSystem (not added to engine)
        renderSystem = new RenderSystem(app.renderer, camera);
        renderSystems.push(renderSystem);

        trace("Created state '" + name + "' with ID " + id + " and camera");
    }
    
    /**
     * Called every frame to update state logic
     * Override in subclasses for state-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;

        // Step all update systems (engine only contains update systems)
        engine.step(deltaTime);

        // Update all active entities in this state (for custom entity logic)
        for (entity in entities) {
            if (entity != null && entity.active) {
                entity.update(deltaTime);
            }
        }

        // Late update all active entities
        for (entity in entities) {
            if (entity != null && entity.active) {
                entity.lateUpdate(deltaTime);
            }
        }
    }
    
    /**
     * Called every frame to render state entities
     * Rendering is now handled by RenderSystem in the Cog engine during update()
     * This method is kept for backward compatibility but is no longer used
     */
    public function render(renderer:Renderer):Void {
        // Step all render systems (RenderSystem, UI, etc.)
        for (sys in renderSystems) sys.step(0);
        // Add post-processing or UI here if needed
    }
    
    /**
     * Add an entity to this state
     */
    public function addEntity(entity:Entity):Entity {
        if (entity == null) {
            trace("Warning: Attempted to add null entity to state '" + name + "'");
            return null;
        }
        
        entities.push(entity);
        entity.state = this;
        
        // Add entity's Cog components to the engine
        engine.add_components(entity.components);

        // Initialize DisplayObject from RenderComponent (using Cog component access)
        var renderComp = entity.components.get(RenderComponent);
        if (renderComp != null && renderComp.displayObject != null && !renderComp.displayObject.active) {
            renderComp.displayObject.init(__app.renderer);
            trace("Initialized DisplayObject for entity '" + entity.id + "'");
        }
        
        trace("Added entity '" + entity.id + "' to state '" + name + "'");
        return entity;
    }
    
    /**
     * Remove an entity from this state
     */
    public function removeEntity(entity:Entity):Bool {
        if (entity == null) return false;
        
        var removed = entities.remove(entity);
        if (removed) {
            entity.state = null;
            
            // Remove entity's components from Cog engine
            engine.remove_components(entity.components);
            
            trace("Removed entity '" + entity.id + "' from state '" + name + "'");
        }
        return removed;
    }
    
    /**
     * Remove entity by ID
     */
    public function removeEntityById(id:String):Bool {
        for (entity in entities) {
            if (entity.id == id) {
                return removeEntity(entity);
            }
        }
        return false;
    }
    
    /**
     * Find entity by ID
     */
    public function getEntity(id:String):Entity {
        for (entity in entities) {
            if (entity.id == id) {
                return entity;
            }
        }
        return null;
    }
    
    /**
     * Get all entities of a specific type
     */
    public function getEntitiesByType<T:Entity>(type:Class<T>):Array<T> {
        var result:Array<T> = [];
        for (entity in entities) {
            if (Std.isOfType(entity, type)) {
                result.push(cast entity);
            }
        }
        return result;
    }
    
    /**
     * Get all entities that have a specific component
     */
    public function getEntitiesWithComponent<T:Component>(componentClass:Class<T>):Array<Entity> {
        var result:Array<Entity> = [];
        for (entity in entities) {
            if (entity.hasComponent(componentClass)) {
                result.push(entity);
            }
        }
        return result;
    }
    
    /**
     * Clear all entities from this state
     */
    public function clearEntities(renderer:Renderer):Void {
        trace("Clearing " + entities.length + " entities from state '" + name + "'");
        for (entity in entities) {
            if (entity != null) {
                entity.state = null;
                // Cleanup entity (this will cleanup all components including DisplayObject)
                entity.cleanup(renderer);
            }
        }
        entities = [];
    }
    
    public function init():Void {
        active = true;
    }
    
    public function release():Void {
        trace("State '" + name + "' released");
        active = false;
    }
    
    /**
     * Get current entity count
     */
    public function getEntityCount():Int {
        return entities.length;
    }
    
    /**
     * Get debug info about this state
     */
    public function getDebugInfo():String {
        return 'State "${name}" (ID: ${id}) - Entities: ${entities.length}, Active: ${active}';
    }
    
    /**
     * Get app reference
     */
    private function get_app():App {
        return __app;
    }
}