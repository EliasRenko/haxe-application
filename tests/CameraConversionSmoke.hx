class CameraConversionSmoke {
	static function checkNear(actual:Float, expected:Float, message:String):Void {
		if (!Math.isFinite(actual) || Math.abs(actual - expected) > 0.000001)
			throw '$message: expected $expected, got $actual';
	}

	static function checkPoint(actual:{x:Float, y:Float}, x:Float, y:Float, message:String):Void {
		checkNear(actual.x, x, message + " x");
		checkNear(actual.y, y, message + " y");
	}

	static function checkThrows(action:()->Void, message:String):Void {
		var thrown = false;
		try {
			action();
		} catch (error:Dynamic) {
			thrown = true;
		}
		if (!thrown) throw message;
	}

	static function checkRoundTrip(camera:Camera, x:Float, y:Float, width:Float, height:Float):Void {
		var screen = camera.worldToScreen2D(x, y, width, height);
		var matrix = camera.getProjectionMatrix().data;
		checkPoint(screen,
			(matrix[0] * x + matrix[4] * y + matrix[12] + 1) * width * 0.5,
			(1 - matrix[1] * x - matrix[5] * y - matrix[13]) * height * 0.5,
			"screen position matches shader projection");
		checkPoint(camera.screenToWorld2D(screen.x, screen.y, width, height), x, y, "round trip");
	}

	static function main():Void {
		var camera = new Camera();
		camera.ortho = true;
		camera.viewWidth = 800;
		camera.viewHeight = 600;
		camera.x = 30;
		camera.y = -10;
		camera.zoom = 2;
		camera.zoomCenterX = 100;
		camera.zoomCenterY = 75;

		checkPoint(camera.worldToScreen2D(130, 65, 400, 300), 200, 150, "projection center on HiDPI");
		checkPoint(camera.screenToWorld2D(210, 160, 400, 300), 140, 75, "HiDPI picking");
		checkPoint(camera.worldToScreen2D(140, 75, 800, 600), 420, 320, "pixel-sized screen");
		checkRoundTrip(camera, -25, 180, 400, 300);
		var picked = camera.screenToWorld2D(13, 290, 400, 300);
		checkPoint(camera.worldToScreen2D(picked.x, picked.y, 400, 300), 13, 290, "screen round trip");
		camera.zoomCenterX = null;
		camera.zoomCenterY = null;
		checkPoint(camera.worldToScreen2D(430, 290, 400, 300), 200, 150, "default projection center");

		camera.viewWidth = 1200;
		camera.viewHeight = 500;
		camera.zoomCenterX = 70;
		camera.zoomCenterY = 130;
		checkRoundTrip(camera, 42, -80, 600, 400);

		var before = camera.screenToWorld2D(80, 120, 600, 400);
		camera.zoom = 3;
		var after = camera.screenToWorld2D(80, 120, 600, 400);
		camera.x += before.x - after.x;
		camera.y += before.y - after.y;
		checkPoint(camera.screenToWorld2D(80, 120, 600, 400), before.x, before.y, "anchored zoom");

		var previous = camera.screenToWorld2D(80, 120, 600, 400);
		var current = camera.screenToWorld2D(125, 160, 600, 400);
		camera.x += previous.x - current.x;
		camera.y += previous.y - current.y;
		checkPoint(camera.screenToWorld2D(125, 160, 600, 400), previous.x, previous.y, "pan anchor");

		camera.pitch = 25;
		checkThrows(() -> camera.worldToScreen2D(0, 0, 600, 400), "pitch must be rejected");
		camera.pitch = 0;
		camera.yaw = -20;
		checkThrows(() -> camera.screenToWorld2D(0, 0, 600, 400), "yaw must be rejected");
		camera.yaw = 0;
		camera.roll = 35;
		checkThrows(() -> camera.worldToScreen2D(0, 0, 600, 400), "roll must be rejected");
		camera.roll = 0;
		checkThrows(() -> camera.zoom = 0, "zero zoom must be rejected");
		camera.zoom = 1;
		checkThrows(() -> camera.screenToWorld2D(0, 0, 0, 400), "zero screen size must be rejected");
		camera.ortho = false;
		checkThrows(() -> camera.worldToScreen2D(0, 0, 600, 400), "perspective must be rejected");
		trace("Camera conversion smoke test passed");
	}
}
