package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import haxe.io.Path;
#end

/**
 * EntityMacro - Compile-time utilities for self-registering entity classes.
 *
 * buildInit() is used via @:build(EntityMacro.buildInit()) on EntityClasses.
 * reg() is called from each entity's __reg static field initializer.
 */
class EntityMacro {

    /**
     * Shorthand for entity self-registration.
     * Automatically uses the calling class name as the registry key —
     * no string literal needed.
     *
     * Usage inside any entity class:
     *   private static var __reg = EntityMacro.reg((batch, inst, def) -> ...);
     */
    public static macro function reg(factory:haxe.macro.Expr):haxe.macro.Expr {
        var className = haxe.macro.Context.getLocalClass().get().name;
        return macro entity.EntityRegistry.register($v{className}, $factory);
    }

    #if macro

    // Files in src/entity/ that are infrastructure, not registerable entities.
    private static final SKIP:Array<String> = [
        "EntityRegistry",
        "EntityClasses",
        "DisplayEntity"
    ];

    /**
     * @:build macro for EntityClasses.
     * Scans src/entity/, finds classes with a __reg field, and emits a
     * reference to each one inside EntityClasses.init() to prevent DCE
     * and guarantee their static initializers run at startup.
     */
    public static function buildInit():Array<Field> {
        var fields = Context.getBuildFields();
        var pos    = Context.currentPos();
        var exprs:Array<Expr> = [];

        var entityDir = "src/entity";

        if (FileSystem.exists(entityDir) && FileSystem.isDirectory(entityDir)) {
            for (file in FileSystem.readDirectory(entityDir)) {
                if (Path.extension(file) != "hx") continue;

                var clsName = Path.withoutExtension(file);
                if (SKIP.contains(clsName)) continue;

                var fullName = "entity." + clsName;
                try {
                    var type = Context.getType(fullName);
                    switch type {
                        case TInst(t, _):
                            var statics = t.get().statics.get();
                            if (Lambda.exists(statics, f -> f.name == "__reg")) {
                                exprs.push(macro $p{["entity", clsName]});
                                Context.info("EntityMacro: auto-registered " + fullName, pos);
                            }
                        default:
                    }
                } catch (_) {
                    // Type unavailable at this build phase — skip silently.
                }
            }
        }

        for (field in fields) {
            if (field.name == "init") {
                switch field.kind {
                    case FFun(f): f.expr = macro $b{exprs};
                    default:
                }
            }
        }

        return fields;
    }

    #end
}
