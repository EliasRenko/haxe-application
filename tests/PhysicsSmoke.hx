import differ.shapes.Circle;
import differ.shapes.Polygon;

class PhysicsSmoke {
    static function check(ok:Bool, message:String):Void {
        if (!ok) throw message;
    }

    static function main():Void {
        var physics = new Physics(null, 10);
        var entityA = new Entity("a");
        var entityB = new Entity("b");
        var circleA = new Circle(0, 0, 12);
        var circleB = new Circle(1, 0, 12);

        physics.addCollider(entityA, circleA);
        physics.addCollider(entityB, circleB);
        check(physics.update().length == 1, "A collider pair spanning several cells must be deduplicated");

        circleB.x = 100;
        check(physics.update().length == 0, "Separated AABBs must not produce candidates");

        circleB.x = 0;
        entityB.active = false;
        check(physics.update().length == 0, "Inactive entities must be omitted");
        entityB.active = true;

        var polygon = Polygon.rectangle(0, 0, 10, 10);
        var entityC = new Entity("c");
        physics.addCollider(entityC, polygon);
        check(physics.update().length == 3, "All distinct overlapping entity pairs must be returned");

        physics.removeEntity(entityC);
        check(physics.update().length == 1, "Removing an entity must remove its colliders");
        trace("Physics broad-phase smoke test passed");
    }
}
