import physics.shapes.Circle;
import physics.shapes.Polygon;
import physics.shapes.Shape;

/**
 * Uniform-grid broad phase for entity collision shapes.
 * The returned candidates are only possible AABB overlaps; callers should
 * use the narrow-phase collision queries to confirm actual contacts.
 */
class Physics {
    public var cellSize(default, null):Float;
    public var candidates(default, null):Array<PhysicsPair> = [];

    private var owner:State;
    private var colliders:Array<PhysicsCollider> = [];
    private var grid:Map<String, Array<PhysicsCollider>> = new Map();
    private var nextColliderId:Int = 0;

    public function new(owner:State, cellSize:Float = 128) {
        if (!(cellSize > 0) || cellSize == Math.POSITIVE_INFINITY) {
            throw "Physics cell size must be a positive finite number";
        }

        this.owner = owner;
        this.cellSize = cellSize;
    }

    /**
     * Register a circle or polygon for broad-phase checks.
     * The entity must already belong to this physics world's state.
     */
    public function addCollider(entity:Entity, shape:Shape):Void {
        if (entity == null || shape == null) {
            throw "Physics requires a non-null entity and shape";
        }
        if (owner != null && entity.state != owner) {
            throw "Physics collider entity must belong to its owning state";
        }
        if (!Std.isOfType(shape, Circle) && !Std.isOfType(shape, Polygon)) {
            throw "Physics supports Circle and Polygon colliders";
        }
        if (Std.isOfType(shape, Polygon) && cast(shape, Polygon).vertices.length < 3) {
            throw "Physics polygon colliders require at least three vertices";
        }

        for (collider in colliders) {
            if (collider.entity == entity && collider.shape == shape) {
                return;
            }
        }

        colliders.push(new PhysicsCollider(nextColliderId++, entity, shape));
        candidates = [];
    }

    public function removeCollider(entity:Entity, shape:Shape):Bool {
        for (i in 0...colliders.length) {
            var collider = colliders[i];
            if (collider.entity == entity && collider.shape == shape) {
                colliders.splice(i, 1);
                candidates = [];
                return true;
            }
        }
        return false;
    }

    public function removeEntity(entity:Entity):Void {
        var removed = false;
        var i = colliders.length - 1;
        while (i >= 0) {
            if (colliders[i].entity == entity) {
                colliders.splice(i, 1);
                removed = true;
            }
            i--;
        }
        if (removed) {
            candidates = [];
        }
    }

    public function clear():Void {
        colliders = [];
        grid = new Map();
        candidates = [];
    }

    /**
     * Rebuild the grid and candidate list from current entity and shape state.
     * The returned list is replaced on each call.
     */
    public function update():Array<PhysicsPair> {
        grid = new Map();
        candidates = [];

        for (collider in colliders) {
            if (!collider.entity.active || !collider.shape.active ||
                (owner != null && collider.entity.state != owner)) {
                continue;
            }

            updateBounds(collider);
            insertIntoGrid(collider);
        }

        var seen:Map<String, Bool> = new Map();
        for (bucket in grid) {
            for (i in 0...bucket.length) {
                var first = bucket[i];
                for (j in i + 1...bucket.length) {
                    var second = bucket[j];
                    if (first.entity == second.entity || !overlaps(first, second)) {
                        continue;
                    }

                    var lowId = first.id < second.id ? first.id : second.id;
                    var highId = first.id < second.id ? second.id : first.id;
                    var key = lowId + ":" + highId;
                    if (!seen.exists(key)) {
                        seen.set(key, true);
                        candidates.push(new PhysicsPair(first.entity, first.shape, second.entity, second.shape));
                    }
                }
            }
        }

        return candidates;
    }

    private function updateBounds(collider:PhysicsCollider):Void {
        var shape = collider.shape;

        if (Std.isOfType(shape, Circle)) {
            var circle:Circle = cast shape;
            var radius = Math.abs(circle.transformedRadius);
            collider.minX = circle.x - radius;
            collider.minY = circle.y - radius;
            collider.maxX = circle.x + radius;
            collider.maxY = circle.y + radius;
            return;
        }

        var polygon:Polygon = cast shape;
        var vertices = polygon.transformedVertices;
        if (vertices.length < 3) {
            throw "Physics polygon colliders require at least three vertices";
        }

        collider.minX = collider.maxX = vertices[0].x;
        collider.minY = collider.maxY = vertices[0].y;
        for (i in 1...vertices.length) {
            var vertex = vertices[i];
            if (vertex.x < collider.minX) collider.minX = vertex.x;
            if (vertex.x > collider.maxX) collider.maxX = vertex.x;
            if (vertex.y < collider.minY) collider.minY = vertex.y;
            if (vertex.y > collider.maxY) collider.maxY = vertex.y;
        }
    }

    private function insertIntoGrid(collider:PhysicsCollider):Void {
        var minCellX = Std.int(Math.floor(collider.minX / cellSize));
        var minCellY = Std.int(Math.floor(collider.minY / cellSize));
        var maxCellX = Std.int(Math.floor(collider.maxX / cellSize));
        var maxCellY = Std.int(Math.floor(collider.maxY / cellSize));
        var endCellX = maxCellX + 1;
        var endCellY = maxCellY + 1;

        for (cellX in minCellX...endCellX) {
            for (cellY in minCellY...endCellY) {
                var key = cellX + ":" + cellY;
                var bucket = grid.get(key);
                if (bucket == null) {
                    bucket = [];
                    grid.set(key, bucket);
                }
                bucket.push(collider);
            }
        }
    }

    private static inline function overlaps(a:PhysicsCollider, b:PhysicsCollider):Bool {
        return a.minX <= b.maxX && a.maxX >= b.minX &&
            a.minY <= b.maxY && a.maxY >= b.minY;
    }
}

private class PhysicsCollider {
    public var id:Int;
    public var entity:Entity;
    public var shape:Shape;
    public var minX:Float = 0;
    public var minY:Float = 0;
    public var maxX:Float = 0;
    public var maxY:Float = 0;

    public function new(id:Int, entity:Entity, shape:Shape) {
        this.id = id;
        this.entity = entity;
        this.shape = shape;
    }
}
