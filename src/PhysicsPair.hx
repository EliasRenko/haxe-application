import differ.shapes.Shape;

/** A pair of entities whose collider AABBs overlap in the broad phase. */
class PhysicsPair {
    public var entityA(default, null):Entity;
    public var shapeA(default, null):Shape;
    public var entityB(default, null):Entity;
    public var shapeB(default, null):Shape;

    public function new(entityA:Entity, shapeA:Shape, entityB:Entity, shapeB:Shape) {
        this.entityA = entityA;
        this.shapeA = shapeA;
        this.entityB = entityB;
        this.shapeB = shapeB;
    }
}
