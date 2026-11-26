import Camera.SizeMode;
import math.Vec2;

class CameraFeaturesSmoke {
	static function near(actual:Float, expected:Float, message:String):Void {
		if (!Math.isFinite(actual) || Math.abs(actual - expected) > 0.000001)
			throw '$message: expected $expected, got $actual';
	}

	static function point(actual:{x:Float, y:Float}, x:Float, y:Float, message:String):Void {
		near(actual.x, x, message + " x");
		near(actual.y, y, message + " y");
	}

	static function expectError(action:()->Void, message:String):Void {
		var failed = false;
		try {
			action();
		} catch (error:Dynamic) {
			failed = true;
		}
		if (!failed) throw message;
	}

	static function main():Void {
		var camera = new Camera();
		camera.ortho = true;
		camera.setViewportSize(800, 600);
		point(camera.size, 800, 600, "default size");
		camera.size = new Vec2(400, 400);
		camera.sizeMode = SizeMode.fit;
		point(camera.screenToWorld2D(0, 0, 800, 600), -200 / 3, 0, "fit");
		camera.sizeMode = SizeMode.cover;
		point(camera.screenToWorld2D(0, 0, 800, 600), 0, 50, "cover");
		camera.sizeMode = SizeMode.contain;
		point(camera.screenToWorld2D(0, 0, 800, 600), 0, 0, "contain");
		camera.zoom = 2;
		point(camera.screenToWorld2D(0, 0, 800, 600), 100, 100, "zoom on virtual size");
		camera.zoom = 1;
		camera.setViewportSize(400, 800);
		camera.sizeMode = SizeMode.fit;
		point(camera.screenToWorld2D(0, 0, 400, 800), 0, -200, "fit after resize");

		camera.setViewportSize(800, 600);
		camera.viewport = {x: 100, y: 50, width: 400, height: 300};
		camera.size = new Vec2(200, 100);
		camera.sizeMode = SizeMode.fit;
		point(camera.worldToScreen2D(100, 50, 400, 300), 150, 100, "viewport center on HiDPI");
		point(camera.screenToWorld2D(50, 25, 400, 300), 0, -25, "viewport top left on HiDPI");
		var m = camera.getProjectionMatrix().data;
		var projected = camera.worldToScreen2D(45, 80, 400, 300);
		point(projected, (100 + 400 * (m[0] * 45 + m[4] * 80 + m[12] + 1) / 2) / 2,
			(50 + 300 * (1 - m[1] * 45 - m[5] * 80 - m[13]) / 2) / 2,
			"viewport conversion matches matrix");
		var copy = camera.size;
		copy.x = 999;
		near(camera.size.x, 200, "size getter returns a copy");
		var viewportCopy = camera.viewport;
		viewportCopy.x = 999;
		near(camera.viewport.x, 100, "viewport getter returns a copy");

		camera.minimumZoom = 2;
		near(camera.zoom, 2, "minimum zoom adjusts current zoom");
		camera.zoom = 0.5;
		near(camera.zoom, 2, "minimum zoom clamps future zoom");
		camera.minimumZoom = 0;
		camera.zoom = 1;
		camera.sizeMode = SizeMode.contain;
		camera.bounds = {x: 0, y: 0, width: 500, height: 200};
		camera.x = 1000;
		camera.y = 1000;
		near(camera.x, 300, "horizontal bounds");
		near(camera.y, 100, "vertical bounds");
		camera.focus(250, 100);
		point(camera.screenToWorld2D(150, 100, 400, 300), 250, 100, "focus");
		camera.bounds = {x: 0, y: 0, width: 50, height: 50};
		point(camera.screenToWorld2D(150, 100, 400, 300), 25, 25, "view larger than bounds");
		expectError(() -> camera.roll = 1, "bounds must reject rotation");
		camera.bounds = {x: 0, y: 0, width: 500, height: 200};
		camera.focus(100, 50);
		camera.shake(100, 1);
		for (i in 0...10) {
			camera.update(0.05);
			var bounded = camera.screenToWorld2D(150, 100, 400, 300);
			if (bounded.x < 100 || bounded.x > 400 || bounded.y < 50 || bounded.y > 150)
				throw "Shake must respect visible-area bounds";
		}
		camera.update(1);
		camera.bounds = null;
		camera.focus(250, 100);
		var baseX = camera.x;
		var baseY = camera.y;
		camera.shake(10, 1);
		camera.update(0.5);
		var shaken = camera.screenToWorld2D(150, 100, 400, 300);
		if (Math.abs(shaken.x - 250) > 5 || Math.abs(shaken.y - 100) > 5)
			throw "Shake must decay over its duration";
		m = camera.getProjectionMatrix().data;
		projected = camera.worldToScreen2D(shaken.x, shaken.y, 400, 300);
		point(projected, (100 + 400 * (m[0] * shaken.x + m[4] * shaken.y + m[12] + 1) / 2) / 2,
			(50 + 300 * (1 - m[1] * shaken.x - m[5] * shaken.y - m[13]) / 2) / 2,
			"shake conversion matches matrix");
		near(camera.x, baseX, "shake preserves camera x");
		near(camera.y, baseY, "shake preserves camera y");
		camera.update(0.5);
		point(camera.screenToWorld2D(150, 100, 400, 300), 250, 100, "shake ends");
		expectError(() -> camera.shake(-1, 1), "negative shake must fail");
		expectError(() -> camera.update(-1), "negative delta must fail");
		expectError(() -> camera.size = new Vec2(0, 1), "invalid size must fail");
		expectError(() -> camera.viewport = {x: 0, y: 0, width: 0, height: 1}, "invalid viewport must fail");
		camera.size = null;
		point(camera.size, 400, 300, "reset size follows viewport");
		camera.viewport = null;
		point(camera.size, 800, 600, "reset viewport follows window");
		camera.ortho = false;
		expectError(() -> camera.size = new Vec2(100, 100), "perspective virtual size must fail");

		var resized = new Camera();
		resized.ortho = true;
		resized.setViewportSize(800, 600);
		resized.bounds = {x: 0, y: 0, width: 1000, height: 800};
		resized.x = 200;
		resized.setViewportSize(900, 600);
		near(resized.x, 100, "bounds update after resize");
		trace("Camera features smoke test passed");
	}
}
