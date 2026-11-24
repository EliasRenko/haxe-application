package states;

import display.LineBatch;
import physics.shapes.Circle;
import physics.shapes.Polygon;
import physics.shapes.Ray;
import physics.shapes.Shape;
import physics.data.ShapeCollision;
import physics.data.RayCollision;
import math.Vec2;
import ScanCode;

/**
 * Minimal physics collision test.
 *
 *   WASD / Arrow keys - move the controlled shape or ray origin
 *   Q / E              - previous / next physics demo
 *   Mouse              - aim the ray in the Ray demo
 *   ESCAPE             - return to the menu
 */
class PhysicsState extends State {

    private static inline var PLAYER_WIDTH:Float = 70.0;
    private static inline var PLAYER_HEIGHT:Float = 70.0;
    private static inline var STATIC_WIDTH:Float = 110.0;
    private static inline var STATIC_HEIGHT:Float = 110.0;
    private static inline var MOVE_SPEED:Float = 220.0;

    private static final DEMO_NAMES:Array<String> = ["Rectangles", "Circles", "Ray"];

    private var player:PhysicsShapeEntity;
    private var obstacle:PhysicsShapeEntity;
    private var lineBatch:LineBatch;
    private var colliding:Bool = false;
    private var wasColliding:Bool = false;
    private var demoIndex:Int = 0;
    private var ray:Ray;
    private var rayHit:RayCollision;

    public function new(app:App) {
        super("Physics", app);
    }

    override public function init():Void {
        super.init();

        camera.ortho = true;

        lineBatch = new LineBatch(app.renderer, false);
        setupDemo(0);
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        if (app.input.keyboard.released(ScanCode.ESCAPE)) {
            app.switchToStateByName("Menu");
            return;
        }

        if (app.input.keyboard.released(ScanCode.Q)) {
            setupDemo((demoIndex - 1 + DEMO_NAMES.length) % DEMO_NAMES.length);
        }
        if (app.input.keyboard.released(ScanCode.E)) {
            setupDemo((demoIndex + 1) % DEMO_NAMES.length);
        }

        var dx:Float = 0;
        var dy:Float = 0;

        if (app.input.keyboard.check(ScanCode.LEFT) || app.input.keyboard.check(ScanCode.A))
            dx -= 1;
        if (app.input.keyboard.check(ScanCode.RIGHT) || app.input.keyboard.check(ScanCode.D))
            dx += 1;
        if (app.input.keyboard.check(ScanCode.UP) || app.input.keyboard.check(ScanCode.W))
            dy -= 1;
        if (app.input.keyboard.check(ScanCode.DOWN) || app.input.keyboard.check(ScanCode.S))
            dy += 1;

        if (dx != 0 || dy != 0) {
            var length = Math.sqrt(dx * dx + dy * dy);
            dx = dx / length * MOVE_SPEED * deltaTime;
            dy = dy / length * MOVE_SPEED * deltaTime;
        }

        if (dx != 0) {
            player.hitbox.x += dx;
            clampPlayer();
            physics.update();

            if (demoIndex == 0 && testOverlap())
                resolveHorizontalCollision(dx);
            else if (demoIndex == 1 && testOverlap())
                resolveCircleCollision();
        }

        if (dy != 0) {
            player.hitbox.y += dy;
            clampPlayer();
            physics.update();

            if (demoIndex == 0 && testOverlap())
                resolveVerticalCollision(dy);
            else if (demoIndex == 1 && testOverlap())
                resolveCircleCollision();
        }

        physics.update();
        if (demoIndex != 2)
            colliding = testContact();
        else
            updateRay();

        if (colliding != wasColliding) {
            if (colliding) {
                trace("Physics collision detected: Player vs Obstacle");
            } else {
                trace("Physics collision ended");
            }
            wasColliding = colliding;
        }
    }

    override public function render(renderer:Renderer):Void {
        if (!active) return;

        lineBatch.clear();

        if (demoIndex == 0) {
            _drawPolygon(cast player.hitbox, colliding
                ? [1.0, 0.25, 0.25, 1.0]
                : [0.25, 1.0, 0.25, 1.0]);
            _drawPolygon(cast obstacle.hitbox, [0.35, 0.65, 1.0, 1.0]);
        } else if (demoIndex == 1) {
            _drawCircle(cast player.hitbox, colliding
                ? [1.0, 0.25, 0.25, 1.0]
                : [0.25, 1.0, 0.25, 1.0]);
            _drawCircle(cast obstacle.hitbox, [0.35, 0.65, 1.0, 1.0]);
        } else {
            _drawCircle(cast player.hitbox, [0.25, 1.0, 0.25, 1.0]);
            _drawPolygon(cast obstacle.hitbox, [0.35, 0.65, 1.0, 1.0]);
            _drawRay(ray, rayHit != null
                ? [1.0, 0.25, 0.25, 1.0]
                : [0.25, 0.75, 1.0, 1.0]);
        }

        lineBatch.render(renderer);
    }

    private function setupDemo(index:Int):Void {
        demoIndex = index;
        colliding = false;
        wasColliding = false;
        rayHit = null;

        if (player != null) removeEntity(player);
        if (obstacle != null) removeEntity(obstacle);
        physics.clear();

        var size = app.window.size;

        if (demoIndex == 0) {
            player = new PhysicsShapeEntity(
                "Player",
                Polygon.rectangle(size.x * 0.35, size.y * 0.5, PLAYER_WIDTH, PLAYER_HEIGHT)
            );
            obstacle = new PhysicsShapeEntity(
                "Obstacle",
                Polygon.rectangle(size.x * 0.65, size.y * 0.5, STATIC_WIDTH, STATIC_HEIGHT)
            );
        } else if (demoIndex == 1) {
            player = new PhysicsShapeEntity(
                "Player",
                new Circle(size.x * 0.35, size.y * 0.5, 38)
            );
            obstacle = new PhysicsShapeEntity(
                "Obstacle",
                new Circle(size.x * 0.65, size.y * 0.5, 58)
            );
        } else {
            player = new PhysicsShapeEntity(
                "RayOrigin",
                new Circle(size.x * 0.15, size.y * 0.5, 10)
            );
            obstacle = new PhysicsShapeEntity(
                "RayTarget",
                Polygon.rectangle(size.x * 0.65, size.y * 0.5, 130, 130)
            );
        }

        addEntity(player);
        addEntity(obstacle);

        if (demoIndex != 2) {
            physics.addCollider(player, player.hitbox);
            physics.addCollider(obstacle, obstacle.hitbox);
        } else {
            updateRay();
        }

        trace("Physics demo: " + DEMO_NAMES[demoIndex]);
    }

    private function clampPlayer():Void {
        var size = app.window.size;
        var radius = 0.0;
        var halfWidth = PLAYER_WIDTH * 0.5;
        var halfHeight = PLAYER_HEIGHT * 0.5;

        if (Std.isOfType(player.hitbox, Circle))
            radius = cast(player.hitbox, Circle).transformedRadius;
        if (radius > 0) {
            halfWidth = radius;
            halfHeight = radius;
        }

        if (player.hitbox.x < halfWidth)
            player.hitbox.x = halfWidth;
        if (player.hitbox.x > size.x - halfWidth)
            player.hitbox.x = size.x - halfWidth;
        if (player.hitbox.y < halfHeight)
            player.hitbox.y = halfHeight;
        if (player.hitbox.y > size.y - halfHeight)
            player.hitbox.y = size.y - halfHeight;
    }

    private function resolveHorizontalCollision(moveX:Float):Void {
        var obstacleLeft = obstacle.hitbox.x - STATIC_WIDTH * 0.5;
        var obstacleRight = obstacle.hitbox.x + STATIC_WIDTH * 0.5;

        if (moveX > 0)
            player.hitbox.x = obstacleLeft - PLAYER_WIDTH * 0.5;
        else if (moveX < 0)
            player.hitbox.x = obstacleRight + PLAYER_WIDTH * 0.5;

        clampPlayer();
    }

    private function resolveVerticalCollision(moveY:Float):Void {
        var obstacleTop = obstacle.hitbox.y - STATIC_HEIGHT * 0.5;
        var obstacleBottom = obstacle.hitbox.y + STATIC_HEIGHT * 0.5;

        if (moveY > 0)
            player.hitbox.y = obstacleTop - PLAYER_HEIGHT * 0.5;
        else if (moveY < 0)
            player.hitbox.y = obstacleBottom + PLAYER_HEIGHT * 0.5;

        clampPlayer();
    }

    private function resolveCircleCollision():Void {
        var playerCircle = cast(player.hitbox, Circle);
        var obstacleCircle = cast(obstacle.hitbox, Circle);
        var dx = playerCircle.x - obstacleCircle.x;
        var dy = playerCircle.y - obstacleCircle.y;
        var length = Math.sqrt(dx * dx + dy * dy);
        var radius = playerCircle.transformedRadius + obstacleCircle.transformedRadius;

        if (length < 0.0001) {
            dx = 1;
            dy = 0;
            length = 1;
        }

        var normalX = dx / length;
        var normalY = dy / length;
        playerCircle.x = obstacleCircle.x + normalX * radius;
        playerCircle.y = obstacleCircle.y + normalY * radius;
        clampPlayer();
    }

    private function updateRay():Void {
        var startX = player.hitbox.x;
        var startY = player.hitbox.y;
        var endX = app.input.mouse.x;
        var endY = app.input.mouse.y;

        ray = new Ray(new Vec2(startX, startY), new Vec2(endX, endY), not_infinite);

        if (Std.isOfType(obstacle.hitbox, Polygon)) {
            rayHit = obstacle.hitbox.testRay(ray);
        } else {
            rayHit = cast(obstacle.hitbox, Circle).testRay(ray);
        }
        colliding = rayHit != null;
    }

    private function testOverlap():Bool {
        for (pair in physics.candidates) {
            var collision:ShapeCollision = pair.shapeA.test(pair.shapeB);
            if (collision != null && collision.overlap > 0) {
                return true;
            }

            var a = shapeBounds(pair.shapeA);
            var b = shapeBounds(pair.shapeB);
            if (a != null && b != null &&
                a.minX < b.maxX && a.maxX > b.minX &&
                a.minY < b.maxY && a.maxY > b.minY) {
                return true;
            }
        }
        return false;
    }

    private function testContact():Bool {
        for (pair in physics.candidates) {
            var a = shapeBounds(pair.shapeA);
            var b = shapeBounds(pair.shapeB);
            if (a != null && b != null &&
                a.minX <= b.maxX && a.maxX >= b.minX &&
                a.minY <= b.maxY && a.maxY >= b.minY) {
                return true;
            }
        }
        return false;
    }

    private function shapeBounds(shape:Shape):Null<{minX:Float, minY:Float, maxX:Float, maxY:Float}> {
        if (Std.isOfType(shape, Circle)) {
            var circle = cast(shape, Circle);
            var radius = circle.transformedRadius;
            return {
                minX: circle.x - radius,
                minY: circle.y - radius,
                maxX: circle.x + radius,
                maxY: circle.y + radius
            };
        }
        if (!Std.isOfType(shape, Polygon)) return null;

        var polygon = cast(shape, Polygon);
        var vertices = polygon.transformedVertices;
        if (vertices == null || vertices.length == 0) return null;

        var minX = vertices[0].x;
        var minY = vertices[0].y;
        var maxX = minX;
        var maxY = minY;

        for (i in 1...vertices.length) {
            if (vertices[i].x < minX) minX = vertices[i].x;
            if (vertices[i].y < minY) minY = vertices[i].y;
            if (vertices[i].x > maxX) maxX = vertices[i].x;
            if (vertices[i].y > maxY) maxY = vertices[i].y;
        }

        return {minX: minX, minY: minY, maxX: maxX, maxY: maxY};
    }

    private function _drawPolygon(hitbox:Polygon, color:Array<Float>):Void {
        var vertices = hitbox.transformedVertices;
        if (vertices == null || vertices.length < 3) return;

        for (i in 0...vertices.length) {
            var next = (i + 1) % vertices.length;
            lineBatch.addLine(
                vertices[i].x,
                vertices[i].y,
                0,
                vertices[next].x,
                vertices[next].y,
                0,
                color,
                color
            );
        }
    }

    private function _drawCircle(hitbox:Circle, color:Array<Float>):Void {
        var segments = 32;
        var radius = hitbox.transformedRadius;
        var previousX = hitbox.x + radius;
        var previousY = hitbox.y;

        for (i in 1...segments + 1) {
            var angle = i * Math.PI * 2 / segments;
            var x = hitbox.x + Math.cos(angle) * radius;
            var y = hitbox.y + Math.sin(angle) * radius;
            lineBatch.addLine(previousX, previousY, 0, x, y, 0, color, color);
            previousX = x;
            previousY = y;
        }
    }

    private function _drawRay(value:Ray, color:Array<Float>):Void {
        lineBatch.addLine(
            value.start.x,
            value.start.y,
            0,
            value.end.x,
            value.end.y,
            0,
            color,
            color
        );

        if (rayHit != null) {
            var x = rayHit.ray.start.x + rayHit.ray.dir.x * rayHit.start;
            var y = rayHit.ray.start.y + rayHit.ray.dir.y * rayHit.start;
            var size = 8.0;
            lineBatch.addLine(x - size, y, 0, x + size, y, 0,
                [1.0, 1.0, 0.25, 1.0], [1.0, 1.0, 0.25, 1.0]);
            lineBatch.addLine(x, y - size, 0, x, y + size, 0,
                [1.0, 1.0, 0.25, 1.0], [1.0, 1.0, 0.25, 1.0]);
        }
    }
}

private class PhysicsShapeEntity extends Entity {
    public var hitbox(default, null):Shape;

    public function new(id:String, hitbox:Shape) {
        super(id);
        this.hitbox = hitbox;
    }
}
