import math.Matrix;

class CameraRotationSmoke {
	static function checkNear(actual:Float, expected:Float, message:String):Void {
		if (Math.isNaN(actual) || Math.abs(actual - expected) > 0.000001)
			throw '$message: expected $expected, got $actual';
	}

	static function transform(matrix:Matrix, x:Float, y:Float, z:Float):Array<Float> {
		var m = matrix.data;
		return [
			m[0] * x + m[4] * y + m[8] * z + m[12],
			m[1] * x + m[5] * y + m[9] * z + m[13],
			m[2] * x + m[6] * y + m[10] * z + m[14],
			m[3] * x + m[7] * y + m[11] * z + m[15]
		];
	}

	static function worldPoint(camera:Camera, x:Float, y:Float, z:Float):Array<Float> {
		var pitch = camera.pitch * Math.PI / 180;
		var yaw = camera.yaw * Math.PI / 180;
		var roll = camera.roll * Math.PI / 180;
		var py = Math.cos(pitch) * y - Math.sin(pitch) * z;
		var pz = Math.sin(pitch) * y + Math.cos(pitch) * z;
		var yx = Math.cos(yaw) * x + Math.sin(yaw) * pz;
		var yz = -Math.sin(yaw) * x + Math.cos(yaw) * pz;
		return [
			camera.x + Math.cos(roll) * yx + Math.sin(roll) * py,
			camera.y - Math.sin(roll) * yx + Math.cos(roll) * py,
			camera.z + yz
		];
	}

	static function checkPose(camera:Camera, pitch:Float, yaw:Float, roll:Float):Void {
		camera.pitch = pitch;
		camera.yaw = yaw;
		camera.roll = roll;
		var point = worldPoint(camera, 2, 3, -4);
		var actual = transform(camera.getProjectionMatrix(), point[0], point[1], point[2]);
		var expected:Array<Float>;
		if (camera.ortho) {
			expected = [0.02, -0.06, 0.4, 1];
		} else {
			var f = 1 / Math.tan(camera.fov * Math.PI / 360);
			var depth = camera.farPlane - camera.nearPlane;
			expected = [
				f,
				3 * f,
				4 * (camera.farPlane + camera.nearPlane) / depth
					- 2 * camera.farPlane * camera.nearPlane / depth,
				4
			];
		}
		for (i in 0...4)
			checkNear(actual[i], expected[i], 'clip component $i for ($pitch, $yaw, $roll)');
	}

	static function main():Void {
		var camera = new Camera();
		camera.viewWidth = 200;
		camera.viewHeight = 100;
		camera.x = 11;
		camera.y = -7;
		camera.z = 5;

		for (ortho in [true, false]) {
			camera.ortho = ortho;
			camera.zoomCenterX = 0;
			camera.zoomCenterY = 0;
			checkPose(camera, 0, 0, 0);
			checkPose(camera, 90, 0, 0);
			checkPose(camera, 0, 90, 0);
			checkPose(camera, 0, 0, 90);
			checkPose(camera, 30, -45, 70);
		}
		trace("Camera rotation smoke test passed");
	}
}
