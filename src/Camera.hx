package;

import math.Matrix;

class Camera {

    public var ortho:Bool = false;
    
    // Position
    public var x:Float = 0;
    public var y:Float = 0;
    public var z:Float = 0;
    
    // Zoom factor (for orthographic projection)
    // Values > 1.0 zoom in, values < 1.0 zoom out
    public var zoom:Float = 1.0;
    
    // Zoom center point (in screen coordinates)
    // Zoom will focus on this point. Default is null (uses screen center)
    public var zoomCenterX:Null<Float> = null;
    public var zoomCenterY:Null<Float> = null;
    
    // 3D Rotation (in degrees for easier use)
    public var pitch(get, set):Float;  // X-axis rotation
    public var yaw(get, set):Float;    // Y-axis rotation  
    public var roll(get, set):Float;   // Z-axis rotation
    
    // 3D Camera properties
    public var fov:Float = 45.0; // Field of view in degrees
    public var nearPlane:Float = 0.1;
    public var farPlane:Float = 1000.0;

    // ** Privates 

    private var __matrix:Matrix = new Matrix();
    private var __pitch:Float = 0.0;
    private var __roll:Float = 0.0;
    private var __yaw:Float = 0.0;

    public function new() {}

    public function renderMatrix(width:Float, height:Float):Void {

        __matrix.identity();
        
        // Apply camera transformations first (view matrix)
        // Apply camera rotations (convert degrees to radians)
        if (__pitch != 0.0) __matrix.appendRotationX(__pitch * Math.PI / 180.0);
        if (__yaw != 0.0) __matrix.appendRotationY(__yaw * Math.PI / 180.0);
        if (__roll != 0.0) __matrix.appendRotationZ(__roll * Math.PI / 180.0);
        
        // Apply camera translation (negative because we move the world opposite to camera)
        __matrix.appendTranslation(-x, -y, -z);
        
        if (ortho) {
            // Orthographic projection with configurable zoom center
            // Zoom focuses on zoomCenter (default: screen center)
            // This makes zoom feel natural and controllable
            var halfWidth = (width / zoom) * 0.5;
            var halfHeight = (height / zoom) * 0.5;
            var centerX = zoomCenterX != null ? zoomCenterX : width * 0.5;
            var centerY = zoomCenterY != null ? zoomCenterY : height * 0.5;
            
            var left = centerX - halfWidth;
            var right = centerX + halfWidth;
            var top = centerY - halfHeight;
            var bottom = centerY + halfHeight;
            
            var near = -10.0;     // Allow objects behind the camera
            var far = 10.0;       // Allow objects in front of the camera
            __matrix.append(Matrix.createOrthoMatrix(left, right, bottom, top, near, far));
        }
        else {
            // Perspective projection with proper aspect ratio
            var aspect = width / height;
            __matrix.append(Matrix.createPerspectiveMatrix(fov * Math.PI / 180.0, aspect, nearPlane, farPlane));
        }
    }

    public function getMatrix() {
        return __matrix;
    }

    // ** Getters and setters.

    private function get_pitch():Float {
        return __pitch;
    }

    private function set_pitch(value:Float):Float {
        return __pitch = value % 360;
    }

    private function get_roll():Float {
        return __roll;
    }

    private function set_roll(value:Float):Float {
        return __roll = value % 360;
    }

    private function get_yaw():Float {
        return __yaw;
    }

    private function set_yaw(value:Float):Float {
        return __yaw = value % 360;
    }
}