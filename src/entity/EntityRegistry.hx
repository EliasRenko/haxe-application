package entity;

import Entity;

/**
 * Factory function type.  Each entity class registers one of these.
 *
 * @param batch  The ManagedTileBatch for this entity's tileset.  The factory
 *               can call batch.addTile() zero, one, or many times as needed,
 *               or ignore it entirely for non-visual entities.
 * @param inst   The raw JSON placement object (x, y, plus any custom
 *               per-instance properties set in the editor).
 * @param def    The entity type definition (width, height, class, region
 *               coordinates, and any type-level custom properties).
 */
typedef EntityFactory = (batch:display.ManagedTileBatch, inst:Dynamic, def:Dynamic) -> Entity;

class EntityRegistry {

    private static var _factories:Map<String, EntityFactory> = new Map();

    /**
     * Register a factory for a given class name.
     * Prefer calling EntityMacro.reg() from entity classes — it fills
     * the name in automatically from the calling class name.
     */
    public static function register(name:String, factory:EntityFactory):Bool {
        _factories.set(name, factory);
        trace('EntityRegistry: registered "$name"');
        return true;
    }

    /**
     * Create an entity by class name, forwarding the full JSON context.
     * @param batch  The ManagedTileBatch for this entity's tileset.
     * @param inst   Placement instance data from the map.
     * @param def    Entity type definition from the map.
     * @return  The new Entity, or null if no factory is registered.
     */
    public static function create(name:String, batch:display.ManagedTileBatch, inst:Dynamic, def:Dynamic):Entity {
        var factory = _factories.get(name);
        if (factory == null) {
            trace('EntityRegistry: no factory for "$name"');
            return null;
        }
        return factory(batch, inst, def);
    }

    /**
     * Check whether a class name has a factory registered.
     */
    public static function has(name:String):Bool {
        return _factories.exists(name);
    }

    /**
     * List all registered names — handy for debugging.
     */
    public static function getRegistered():Array<String> {
        return [for (k in _factories.keys()) k];
    }
}
