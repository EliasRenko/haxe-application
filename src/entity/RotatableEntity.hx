package entity;

import EntityMacro;
import entity.TileEntity;

/**
 * A map entity that can rotate its visual tile over time.
 *
 * Extends TileEntity so it owns its tile reference directly — no components.
 *
 * SELF-REGISTRATION
 * -----------------
 * The static __reg field is evaluated the moment this class is touched
 * (guaranteed by EntityClasses.init()).  It pushes a factory lambda into
 * EntityRegistry, so the map loader can create instances purely by name —
 * no switch-case anywhere.
 */
class RotatableEntity extends TileEntity {

    @:keep
    private static var __reg:Bool = EntityMacro.reg(
        (batch, inst, def) -> {
            var e = new RotatableEntity();
            if (Reflect.hasField(inst, "rotationSpeed")) e.rotationSpeed = inst.rotationSpeed;
            var tileId = batch.addTile(inst.x, inst.y, Std.int(def.width), Std.int(def.height), inst.regionId);
            e.bindTile(batch, tileId);
            return e;
        }
    );

    public var rotation:Float      = 0.0;
    public var rotationSpeed:Float = 20.0; // degrees per second

    public function new() {
        super();
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        rotation = (rotation + rotationSpeed * deltaTime) % 360.0;
        setRotation(rotation);
    }
}
