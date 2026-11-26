package;

import math.Matrix;
import math.Vec2;
import utils.Rect;

enum abstract SizeMode(String) {
	var fit = "fit";
	var cover = "cover";
	var contain = "contain";
}

class Camera {
	// Publics
	public var ortho(get, set):Bool;
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var z(get, set):Float;
	public var zoom(get, set):Float;
	/** Minimum positive zoom; zero disables the minimum. */
	public var minimumZoom(get, set):Float;
	/** Orthographic virtual world size. Assign null to follow the viewport; returned values are copies. */
	public var size(get, set):Null<Vec2>;
	public var sizeMode(get, set):SizeMode;
	/** Optional drawable viewport in top-left-origin window pixels. Null uses the whole window. */
	public var viewport(get, set):Null<Rect>;
	/** Optional world-space bounds for the visible area of an unrotated orthographic camera. */
	public var bounds(get, set):Null<Rect>;
	/** Camera-space projection center; null uses half the virtual size or viewport dimension. */
	public var zoomCenterX(get, set):Null<Float>;
	public var zoomCenterY(get, set):Null<Float>;
	/**
	 * World orientation in degrees. A camera-local vector is rotated around X
	 * (pitch), then Y (yaw), then Z (roll), before adding the camera position.
	 * Positive pitch rotates +Y toward +Z; positive yaw rotates +Z toward +X;
	 * positive roll rotates +X toward -Y, matching Matrix.appendRotationZ.
	 * In perspective mode the camera looks along local -Z.
	 */
	public var pitch(get, set):Float;
	public var yaw(get, set):Float;
	public var roll(get, set):Float;
	public var fov(get, set):Float;
	public var nearPlane(get, set):Float;
	public var farPlane(get, set):Float;
	public var viewWidth(get, set):Float;
	public var viewHeight(get, set):Float;

	// Privates
	private var __dirty:Bool = true;
	private var __matrix:Matrix = new Matrix();
	private var __ortho:Bool = false;
	private var __x:Float = 0;
	private var __y:Float = 0;
	private var __z:Float = 0;
	private var __zoom:Float = 1.0;
	private var __minimumZoom:Float = 0;
	private var __size:Null<Vec2> = null;
	private var __sizeMode:SizeMode = fit;
	private var __viewport:Null<Rect> = null;
	private var __bounds:Null<Rect> = null;
	private var __shakeX:Float = 0;
	private var __shakeY:Float = 0;
	private var __shakeAmount:Float = 0;
	private var __shakeDuration:Float = 0;
	private var __shakeElapsed:Float = 0;
	private var __zoomCenterX:Null<Float> = null;
	private var __zoomCenterY:Null<Float> = null;
	private var __pitch:Float = 0.0;
	private var __roll:Float = 0.0;
	private var __yaw:Float = 0.0;
	private var __fov:Float = 45.0;
	private var __nearPlane:Float = 0.1;
	private var __farPlane:Float = 1000.0;
	private var __viewWidth:Float = 0;
	private var __viewHeight:Float = 0;

	public function new() {}

	public function getProjectionMatrix():Matrix {
		if (!__dirty)
			return __matrix;
		if (__viewWidth <= 0 || __viewHeight <= 0)
			return __matrix;
		enforceBounds();
		__matrix.identity();
		var position = effectivePosition();
		__matrix.appendTranslation(-position.x, -position.y, -__z);
		if (__roll != 0.0) __matrix.appendRotationZ(-__roll * Math.PI / 180.0);
		if (__yaw != 0.0) __matrix.appendRotationY(-__yaw * Math.PI / 180.0);
		if (__pitch != 0.0) __matrix.appendRotationX(-__pitch * Math.PI / 180.0);

		if (__ortho) {
			var visible = visibleSize();
			var halfWidth = visible.x * 0.5;
			var halfHeight = visible.y * 0.5;
			var centerX = projectionCenterX();
			var centerY = projectionCenterY();
			var left = centerX - halfWidth;
			var right = centerX + halfWidth;
			var top = centerY - halfHeight;
			var bottom = centerY + halfHeight;
			__matrix.append(Matrix.createOrthoMatrix(left, right, bottom, top, -10.0, 10.0));
		} else {
			var area = effectiveViewport();
			var aspect = area.width / area.height;
			__matrix.append(Matrix.createPerspectiveMatrix(__fov * Math.PI / 180.0, aspect, __nearPlane, __farPlane));
		}

		__dirty = false;
		return __matrix;
	}

	public function getMatrix():Matrix {
		return __matrix;
	}

	/** Update the drawable window size together, including after a resize. */
	public function setViewportSize(width:Float, height:Float):Void {
		if (!Math.isFinite(width) || !Math.isFinite(height) || width < 0 || height < 0)
			throw "Camera viewport size must be finite and nonnegative";
		if (__viewWidth == width && __viewHeight == height) return;
		__viewWidth = width;
		__viewHeight = height;
		__dirty = true;
		enforceBounds();
	}

	/** Effective drawable viewport in window pixels. */
	public function effectiveViewport():Rect {
		return __viewport != null
			? {x: __viewport.x, y: __viewport.y, width: __viewport.width, height: __viewport.height}
			: {x: 0, y: 0, width: __viewWidth, height: __viewHeight};
	}

	/** Center the unrotated orthographic view on a world point, respecting bounds. */
	public function focus(x:Float, y:Float):Void {
		validate2DConversion(x, y, __viewWidth, __viewHeight);
		__x = x - projectionCenterX();
		__y = y - projectionCenterY();
		__dirty = true;
		enforceBounds();
	}

	/** Shake the rendered camera position, fading to zero over duration seconds. */
	public function shake(amount:Float, duration:Float):Void {
		if (!Math.isFinite(amount) || amount < 0 || !Math.isFinite(duration) || duration <= 0)
			throw "Camera shake requires a nonnegative amount and positive duration";
		__shakeAmount = amount;
		__shakeDuration = duration;
		__shakeElapsed = 0;
		__shakeX = 0;
		__shakeY = 0;
		__dirty = true;
	}

	/** Advance the shake effect in seconds. State calls this once per update. */
	public function update(deltaTime:Float):Void {
		if (!Math.isFinite(deltaTime) || deltaTime < 0)
			throw "Camera update requires a finite nonnegative delta time";
		if (__shakeDuration == 0 || deltaTime == 0) return;
		__shakeElapsed += deltaTime;
		if (__shakeElapsed >= __shakeDuration) {
			__shakeDuration = 0;
			__shakeX = 0;
			__shakeY = 0;
		} else {
			var amount = __shakeAmount * (1 - __shakeElapsed / __shakeDuration);
			__shakeX = (Math.random() * 2 - 1) * amount;
			__shakeY = (Math.random() * 2 - 1) * amount;
		}
		__dirty = true;
	}

	private function projectionCenterX():Float {
		return __zoomCenterX != null ? __zoomCenterX : (__size != null ? __size.x : effectiveViewport().width) * 0.5;
	}

	private function projectionCenterY():Float {
		return __zoomCenterY != null ? __zoomCenterY : (__size != null ? __size.y : effectiveViewport().height) * 0.5;
	}

	private function visibleSize():Vec2 {
		var area = effectiveViewport();
		var scaleX = 1.0;
		var scaleY = 1.0;
		if (__size != null) {
			scaleX = area.width / __size.x;
			scaleY = area.height / __size.y;
			switch (__sizeMode) {
				case fit: scaleX = scaleY = Math.min(scaleX, scaleY);
				case cover: scaleX = scaleY = Math.max(scaleX, scaleY);
				case contain:
			}
		}
		var width = area.width / (scaleX * __zoom);
		var height = area.height / (scaleY * __zoom);
		if (!Math.isFinite(width) || !Math.isFinite(height) || width <= 0 || height <= 0)
			throw "Camera size and zoom produce invalid visible dimensions";
		return new Vec2(width, height);
	}

	private function boundedPosition(x:Float, y:Float):Vec2 {
		if (__bounds == null) return new Vec2(x, y);
		if (!__ortho || __pitch != 0 || __yaw != 0 || __roll != 0)
			throw "Camera bounds require an unrotated orthographic camera";
		var visible = visibleSize();
		var centerX = projectionCenterX();
		var centerY = projectionCenterY();
		var minX = __bounds.x + visible.x * 0.5;
		var maxX = __bounds.x + __bounds.width - visible.x * 0.5;
		var minY = __bounds.y + visible.y * 0.5;
		var maxY = __bounds.y + __bounds.height - visible.y * 0.5;
		var worldCenterX = minX > maxX ? __bounds.x + __bounds.width * 0.5 : Math.max(minX, Math.min(maxX, x + centerX));
		var worldCenterY = minY > maxY ? __bounds.y + __bounds.height * 0.5 : Math.max(minY, Math.min(maxY, y + centerY));
		return new Vec2(worldCenterX - centerX, worldCenterY - centerY);
	}

	private function enforceBounds():Void {
		if (__bounds == null || __viewWidth <= 0 || __viewHeight <= 0) return;
		var position = boundedPosition(__x, __y);
		__x = position.x;
		__y = position.y;
	}

	private function effectivePosition():Vec2 {
		return boundedPosition(__x + __shakeX, __y + __shakeY);
	}

	/**
	 * Projects a point on the world z=0 plane into top-left-origin screen coordinates.
	 * Requires an unrotated orthographic camera.
	 * screenWidth and screenHeight are in the caller's screen units, which may
	 * differ from the pixel-sized camera viewport.
	 */
	public function worldToScreen2D(x:Float, y:Float, screenWidth:Float, screenHeight:Float):{x:Float, y:Float} {
		validate2DConversion(x, y, screenWidth, screenHeight);
		enforceBounds();
		var position = effectivePosition();
		var area = effectiveViewport();
		var visible = visibleSize();
		var screenX = (area.x + area.width * (0.5 + (x - position.x - projectionCenterX()) / visible.x)) * screenWidth / __viewWidth;
		var screenY = (area.y + area.height * (0.5 + (y - position.y - projectionCenterY()) / visible.y)) * screenHeight / __viewHeight;
		if (!Math.isFinite(screenX) || !Math.isFinite(screenY))
			throw "Camera projection produced invalid screen coordinates";
		return {x: screenX, y: screenY};
	}

	/**
	 * Unprojects top-left-origin screen coordinates onto the world z=0 plane.
	 * Requires an unrotated orthographic camera.
	 */
	public function screenToWorld2D(x:Float, y:Float, screenWidth:Float, screenHeight:Float):{x:Float, y:Float} {
		validate2DConversion(x, y, screenWidth, screenHeight);
		enforceBounds();
		var position = effectivePosition();
		var area = effectiveViewport();
		var visible = visibleSize();
		var worldX = position.x + projectionCenterX() + ((x * __viewWidth / screenWidth - area.x) / area.width - 0.5) * visible.x;
		var worldY = position.y + projectionCenterY() + ((y * __viewHeight / screenHeight - area.y) / area.height - 0.5) * visible.y;
		if (!Math.isFinite(worldX) || !Math.isFinite(worldY))
			throw "Camera projection produced invalid world coordinates";
		return {x: worldX, y: worldY};
	}

	private function validate2DConversion(x:Float, y:Float, screenWidth:Float, screenHeight:Float):Void {
		if (!__ortho || __pitch != 0 || __yaw != 0 || __roll != 0)
			throw "2D camera conversion requires an unrotated orthographic camera";
		if (!Math.isFinite(x) || !Math.isFinite(y) || !Math.isFinite(screenWidth) || !Math.isFinite(screenHeight)
			|| screenWidth <= 0 || screenHeight <= 0 || !Math.isFinite(__viewWidth) || !Math.isFinite(__viewHeight)
			|| __viewWidth <= 0 || __viewHeight <= 0 || !Math.isFinite(__zoom) || __zoom <= 0
			|| !Math.isFinite(__x) || !Math.isFinite(__y) || !Math.isFinite(__z)
			|| (__zoomCenterX != null && !Math.isFinite(__zoomCenterX))
			|| (__zoomCenterY != null && !Math.isFinite(__zoomCenterY)))
			throw "2D camera conversion requires finite coordinates, positive viewport dimensions and positive zoom";
	}

	// ** Getters

	private function get_ortho():Bool {
		return __ortho;
	}

	private function get_x():Float {
		return __x;
	}

	private function get_y():Float {
		return __y;
	}

	private function get_z():Float {
		return __z;
	}

	private function get_zoom():Float {
		return __zoom;
	}

	private function get_minimumZoom():Float {
		return __minimumZoom;
	}

	private function get_size():Null<Vec2> {
		if (__size != null) return __size.clone();
		var area = effectiveViewport();
		return new Vec2(area.width, area.height);
	}

	private function get_sizeMode():SizeMode {
		return __sizeMode;
	}

	private function get_viewport():Null<Rect> {
		return __viewport == null ? null : effectiveViewport();
	}

	private function get_bounds():Null<Rect> {
		return __bounds == null ? null : {x: __bounds.x, y: __bounds.y, width: __bounds.width, height: __bounds.height};
	}

	private function get_zoomCenterX():Null<Float> {
		return __zoomCenterX;
	}

	private function get_zoomCenterY():Null<Float> {
		return __zoomCenterY;
	}

	private function get_pitch():Float {
		return __pitch;
	}

	private function get_yaw():Float {
		return __yaw;
	}

	private function get_roll():Float {
		return __roll;
	}

	private function get_fov():Float {
		return __fov;
	}

	private function get_nearPlane():Float {
		return __nearPlane;
	}

	private function get_farPlane():Float {
		return __farPlane;
	}

	private function get_viewWidth():Float {
		return __viewWidth;
	}

	private function get_viewHeight():Float {
		return __viewHeight;
	}

	// ** Setters — each write marks the matrix dirty

	private function set_ortho(v:Bool):Bool {
		if (!v && __bounds != null)
			throw "Camera bounds require an unrotated orthographic camera";
		if (!v && __size != null)
			throw "Camera virtual size requires an orthographic camera";
		__ortho = v;
		__dirty = true;
		return v;
	}

	private function set_x(v:Float):Float {
		__x = v;
		__dirty = true;
		enforceBounds();
		return __x;
	}

	private function set_y(v:Float):Float {
		__y = v;
		__dirty = true;
		enforceBounds();
		return __y;
	}

	private function set_z(v:Float):Float {
		__z = v;
		__dirty = true;
		return v;
	}

	private function set_zoom(v:Float):Float {
		if (!Math.isFinite(v) || v <= 0)
			throw "Camera zoom must be finite and positive";
		__zoom = Math.max(v, __minimumZoom);
		__dirty = true;
		enforceBounds();
		return __zoom;
	}

	private function set_minimumZoom(v:Float):Float {
		if (!Math.isFinite(v) || v < 0)
			throw "Camera minimum zoom must be finite and nonnegative";
		__minimumZoom = v;
		if (__zoom < v) __zoom = v;
		__dirty = true;
		enforceBounds();
		return v;
	}

	private function set_size(v:Null<Vec2>):Null<Vec2> {
		if (v != null && !__ortho)
			throw "Camera virtual size requires an orthographic camera";
		if (v != null && (!Math.isFinite(v.x) || !Math.isFinite(v.y) || v.x <= 0 || v.y <= 0))
			throw "Camera size must have finite positive dimensions";
		__size = v == null ? null : v.clone();
		__dirty = true;
		enforceBounds();
		return get_size();
	}

	private function set_sizeMode(v:SizeMode):SizeMode {
		if (v != fit && v != cover && v != contain)
			throw "Invalid camera size mode";
		__sizeMode = v;
		__dirty = true;
		enforceBounds();
		return v;
	}

	private function set_viewport(v:Null<Rect>):Null<Rect> {
		if (v != null && (!Math.isFinite(v.x) || !Math.isFinite(v.y) || !Math.isFinite(v.width) || !Math.isFinite(v.height)
			|| v.x < 0 || v.y < 0 || v.width <= 0 || v.height <= 0
			|| v.x + v.width > 2147483647 || v.y + v.height > 2147483647
			|| v.x != Math.floor(v.x) || v.y != Math.floor(v.y)
			|| v.width != Math.floor(v.width) || v.height != Math.floor(v.height)))
			throw "Camera viewport requires nonnegative integer position and positive integer dimensions";
		__viewport = v == null ? null : {x: v.x, y: v.y, width: v.width, height: v.height};
		__dirty = true;
		enforceBounds();
		return get_viewport();
	}

	private function set_bounds(v:Null<Rect>):Null<Rect> {
		if (v != null && (!__ortho || __pitch != 0 || __yaw != 0 || __roll != 0))
			throw "Camera bounds require an unrotated orthographic camera";
		if (v != null && (!Math.isFinite(v.x) || !Math.isFinite(v.y) || !Math.isFinite(v.width) || !Math.isFinite(v.height)
			|| v.width <= 0 || v.height <= 0 || !Math.isFinite(v.x + v.width) || !Math.isFinite(v.y + v.height)))
			throw "Camera bounds require finite coordinates and positive dimensions";
		__bounds = v == null ? null : {x: v.x, y: v.y, width: v.width, height: v.height};
		__dirty = true;
		enforceBounds();
		return get_bounds();
	}

	private function set_zoomCenterX(v:Null<Float>):Null<Float> {
		__zoomCenterX = v;
		__dirty = true;
		enforceBounds();
		return v;
	}

	private function set_zoomCenterY(v:Null<Float>):Null<Float> {
		__zoomCenterY = v;
		__dirty = true;
		enforceBounds();
		return v;
	}

	private function set_fov(v:Float):Float {
		__fov = v;
		__dirty = true;
		return v;
	}

	private function set_nearPlane(v:Float):Float {
		__nearPlane = v;
		__dirty = true;
		return v;
	}

	private function set_farPlane(v:Float):Float {
		__farPlane = v;
		__dirty = true;
		return v;
	}

	private function set_viewWidth(v:Float):Float {
		__viewWidth = v;
		__dirty = true;
		enforceBounds();
		return v;
	}

	private function set_viewHeight(v:Float):Float {
		__viewHeight = v;
		__dirty = true;
		enforceBounds();
		return v;
	}

	private function set_pitch(v:Float):Float {
		if (__bounds != null && v % 360 != 0)
			throw "Camera bounds require an unrotated orthographic camera";
		__pitch = v % 360;
		__dirty = true;
		return __pitch;
	}

	private function set_yaw(v:Float):Float {
		if (__bounds != null && v % 360 != 0)
			throw "Camera bounds require an unrotated orthographic camera";
		__yaw = v % 360;
		__dirty = true;
		return __yaw;
	}

	private function set_roll(v:Float):Float {
		if (__bounds != null && v % 360 != 0)
			throw "Camera bounds require an unrotated orthographic camera";
		__roll = v % 360;
		__dirty = true;
		return __roll;
	}
}
