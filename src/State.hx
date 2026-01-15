package;

import Entity;
import Camera;
import App;

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
    
    // Privates
    private var __app:App;
    private static var __nextId:Int = 0;

    private var cameraDebug:Bool = false;
    
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
        
        trace("Created state '" + name + "' with ID " + id + " and camera");
    }
    
    /**
     * Called every frame to update state logic
     * Override in subclasses for state-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;
        
        // Update all active entities in this state
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

        // Debug control: Toggle camera debug mode with 'C' key
        if (app.input.keyboard.released(Keycode.C)) {
            cameraDebug = !cameraDebug;
        }

        // If camera debug mode is active, allow camera movement with arrow keys
        if (cameraDebug) {
            var moveSpeed:Float = 5.0 * deltaTime;
            if (app.input.keyboard.pressed(Keycode.A)) {
                camera.x -= moveSpeed;
            }
            if (app.input.keyboard.pressed(Keycode.D)) {
                camera.x += moveSpeed;
            }
            if (app.input.keyboard.pressed(Keycode.W)) {
                camera.y += moveSpeed;
            }
            if (app.input.keyboard.pressed(Keycode.S)) {
                camera.y -= moveSpeed;
            }
        }

        // If camera debug is active, allow for zooming with W/S keys
        if (cameraDebug) {
            var zoomSpeed:Float = 2.0 * deltaTime;
            if (app.input.keyboard.check(Keycode.W)) {
                // Zoom in (increase zoom factor)
                camera.zoom += zoomSpeed;
                if (camera.zoom > 10.0) camera.zoom = 10.0; // Limit max zoom
            }
            if (app.input.keyboard.check(Keycode.S)) {
                // Zoom out (decrease zoom factor)
                camera.zoom -= zoomSpeed;
                if (camera.zoom < 0.1) camera.zoom = 0.1; // Limit min zoom
            }
        }
    }
    
    /**
     * Called every frame to render state entities
     * Override in subclasses for custom rendering order/effects
     */
    public function render(renderer:Renderer):Void {
        if (!active) return;
        
        // Calculate camera matrix for this state's world
        // This creates the View + Projection matrix

        var size = app.window.size;
        camera.renderMatrix(size.x, size.y);
        var viewProjectionMatrix = camera.getMatrix();
        
        // Render all active and visible entities in this state with the camera matrix
        for (entity in entities) {
            if (entity != null && entity.active && entity.visible) {
                entity.render(renderer, viewProjectionMatrix);
            }
        }
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

    public function onWindowResized(width:Int, height:Int):Void {
        
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