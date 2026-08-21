package;

import math.Matrix;

class Camera {

    public var ortho(get, set):Bool;
    public var x(get, set):Float;
    public var y(get, set):Float;
    public var z(get, set):Float;
    public var zoom(get, set):Float;
    public var zoomCenterX(get, set):Null<Float>;
    public var zoomCenterY(get, set):Null<Float>;
    public var pitch(get, set):Float;
    public var yaw(get, set):Float;
    public var roll(get, set):Float;
    public var fov(get, set):Float;
    public var nearPlane(get, set):Float;
    public var farPlane(get, set):Float;
    public var viewWidth(get, set):Float;
    public var viewHeight(get, set):Float;

    private var __dirty:Bool = true;
    private var __matrix:Matrix = new Matrix();
    private var __ortho:Bool = false;
    private var __x:Float = 0;
    private var __y:Float = 0;
    private var __z:Float = 0;
    private var __zoom:Float = 1.0;
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

    // Returns true if the matrix was rebuilt this frame.
    public function renderMatrix():Bool {
        if (!__dirty) return false;
        __dirty = false;

        __matrix.identity();
        if (__pitch != 0.0) __matrix.appendRotationX(__pitch * Math.PI / 180.0);
        if (__yaw != 0.0) __matrix.appendRotationY(__yaw * Math.PI / 180.0);
        if (__roll != 0.0) __matrix.appendRotationZ(__roll * Math.PI / 180.0);
        __matrix.appendTranslation(-__x, -__y, -__z);

        if (__ortho) {
            var halfWidth = (__viewWidth / __zoom) * 0.5;
            var halfHeight = (__viewHeight / __zoom) * 0.5;
            var centerX = __zoomCenterX != null ? __zoomCenterX : __viewWidth * 0.5;
            var centerY = __zoomCenterY != null ? __zoomCenterY : __viewHeight * 0.5;
            var left   = centerX - halfWidth;
            var right  = centerX + halfWidth;
            var top    = centerY - halfHeight;
            var bottom = centerY + halfHeight;
            __matrix.append(Matrix.createOrthoMatrix(left, right, bottom, top, -10.0, 10.0));
        } else {
            var aspect = __viewWidth / __viewHeight;
            __matrix.append(Matrix.createPerspectiveMatrix(__fov * Math.PI / 180.0, aspect, __nearPlane, __farPlane));
        }
        return true;
    }

    public function getMatrix():Matrix { return __matrix; }

    // ** Getters

    private function get_ortho():Bool         { return __ortho; }
    private function get_x():Float            { return __x; }
    private function get_y():Float            { return __y; }
    private function get_z():Float            { return __z; }
    private function get_zoom():Float         { return __zoom; }
    private function get_zoomCenterX():Null<Float> { return __zoomCenterX; }
    private function get_zoomCenterY():Null<Float> { return __zoomCenterY; }
    private function get_pitch():Float        { return __pitch; }
    private function get_yaw():Float          { return __yaw; }
    private function get_roll():Float         { return __roll; }
    private function get_fov():Float          { return __fov; }
    private function get_nearPlane():Float    { return __nearPlane; }
    private function get_farPlane():Float     { return __farPlane; }
    private function get_viewWidth():Float    { return __viewWidth; }
    private function get_viewHeight():Float   { return __viewHeight; }

    // ** Setters — each write marks the matrix dirty

    private function set_ortho(v:Bool):Bool            { __ortho = v;         __dirty = true; return v; }
    private function set_x(v:Float):Float              { __x = v;             __dirty = true; return v; }
    private function set_y(v:Float):Float              { __y = v;             __dirty = true; return v; }
    private function set_z(v:Float):Float              { __z = v;             __dirty = true; return v; }
    private function set_zoom(v:Float):Float           { __zoom = v;          __dirty = true; return v; }
    private function set_zoomCenterX(v:Null<Float>):Null<Float> { __zoomCenterX = v; __dirty = true; return v; }
    private function set_zoomCenterY(v:Null<Float>):Null<Float> { __zoomCenterY = v; __dirty = true; return v; }
    private function set_fov(v:Float):Float            { __fov = v;           __dirty = true; return v; }
    private function set_nearPlane(v:Float):Float      { __nearPlane = v;     __dirty = true; return v; }
    private function set_farPlane(v:Float):Float       { __farPlane = v;      __dirty = true; return v; }
    private function set_viewWidth(v:Float):Float      { __viewWidth = v;     __dirty = true; return v; }
    private function set_viewHeight(v:Float):Float     { __viewHeight = v;    __dirty = true; return v; }
    private function set_pitch(v:Float):Float          { __pitch = v % 360;   __dirty = true; return __pitch; }
    private function set_yaw(v:Float):Float            { __yaw = v % 360;     __dirty = true; return __yaw; }
    private function set_roll(v:Float):Float           { __roll = v % 360;    __dirty = true; return __roll; }
}