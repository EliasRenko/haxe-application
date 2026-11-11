package;

import Log.LogCategory;
import Entity;
import Camera;
import App;

/**
 * Base class for game states (worlds/scenes/levels)
 * States manage collections of entities and handle state-specific logic
 */
class State {
    
    // State properties
    public var active:Bool = false;
    public var app(get, null):App;
    public var camera:Camera;
    public var entities:Array<Entity> = [];
    public var name:String;
    public var id:Int;
    
    // Privates
    private var __app:App;
    private var __cameraDirty:Bool = true;
    private var __cameraDebug:Bool = true;

    private static var __nextId:Int = 0;
    
    public function new(name:String, app:App) {
        this.name = name;
        this.__app = app;

        this.id = __nextId++;
        this.entities = [];
        
        // Initialize camera for this state
        this.camera = new Camera();
        resetCamera();
        
        app.log.debug(LogCategory.STATE, "Created state '" + name + "' with ID " + id + " and camera");
    }
    
    /**
     * Reset camera to default values
     */
    public function resetCamera():Void {
        camera.ortho = true;
        camera.x = 0.0;
        camera.y = 0.0;
        camera.z = 3.0; // Move camera back to see objects
        camera.pitch = 0.0;
        camera.yaw = 0.0;
        camera.roll = 0.0;
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
        // if (app.input.keyboard.released(Scancode.C)) {
        //     __cameraDebug = !__cameraDebug;
        //     app.log.debug(LogCategory.SYSTEM, "Camera debug mode: " + (__cameraDebug ? "ON" : "OFF"));
        // }

        // if (app.input.keyboard.released(Scancode.R)) {
        //     resetCamera();
        //     app.log.debug(LogCategory.SYSTEM, "Camera reset to default position");
        // }

        // // If camera debug mode is active, allow camera movement with arrow keys
        // if (__cameraDebug) {
            
        //     var moveSpeed:Float = 1000.0 * deltaTime;
        //     if (app.input.keyboard.check(Scancode.A)) {
        //         camera.x -= moveSpeed;
        //         //app.log.debug(LogCategory.SYSTEM, "DeltaTime: " + deltaTime);
        //     }
        //     if (app.input.keyboard.check(Scancode.D)) {
        //         camera.x += moveSpeed;
        //     }
        //     if (app.input.keyboard.check(Scancode.S)) {
        //         camera.y += moveSpeed;
        //     }
        //     if (app.input.keyboard.check(Scancode.W)) {
        //         camera.y -= moveSpeed;
        //     }
        // }

        // // If camera debug is active, allow for zooming with E/Q keys
        // if (cameraDebug) {
        //     var zoomSpeed:Float = 2.0 * deltaTime;
        //     if (app.input.keyboard.check(Scancode.E)) {
        //         // Zoom in (increase zoom factor)
        //         camera.zoom += zoomSpeed;
        //         if (camera.zoom > 10.0) camera.zoom = 10.0; // Limit max zoom
        //     }
        //     if (app.input.keyboard.check(Scancode.Q)) {
        //         // Zoom out (decrease zoom factor)
        //         camera.zoom -= zoomSpeed;
        //         if (camera.zoom < 0.1) camera.zoom = 0.1; // Limit min zoom
        //     }
        // }
    }
    
    public function preRender(renderer:Renderer):Void {
        if (!active) return;

        var size = app.window.size;
        camera.viewWidth = size.x;
        camera.viewHeight = size.y;
        __cameraDirty = camera.getProjectionMatrix(); // TODO: Kinda weird, must improve
        renderer.matrix = camera.getMatrix(); // TODO: Make better and more elegant 
    }

    /**
     * Called every frame to render state entities
     * Override in subclasses for custom rendering order/effects
     */
    public function render(renderer:Renderer):Void {
        if (!active) return;
        
        for (entity in entities) {
            if (entity != null && entity.active && entity.visible) {
                entity.render(renderer);
            }
        }
    }
    
    /**
     * Add an entity to this state
     */
    public function addEntity(entity:Entity):Entity {
        if (entity == null) {
            return null;
        }
        
        entities.push(entity);
        entity.state = this;
        
        app.log.debug(LogCategory.STATE, "Added entity '" + entity.id + "' to state '" + name + "'");
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
            app.log.debug(LogCategory.STATE, "Removed entity '" + entity.id + "' from state '" + name + "'");
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
        // Called once when the state is added to the app.
    }

    public function release():Void {
        clearEntities(app.renderer);
    }

    public function onActivate():Void {
        active = true;
        app.log.debug(LogCategory.STATE, "State '" + name + "' activated");
    }

    public function onDeactivate():Void {
        active = false;
        app.log.debug(LogCategory.STATE, "State '" + name + "' deactivated");
    }

    public function onWindowResized(width:Int, height:Int):Void {}
    
    public function getEntityCount():Int {
        return entities.length;
    }
    
    /**
     * Get app reference
     */
    private function get_app():App {
        return __app;
    }
}