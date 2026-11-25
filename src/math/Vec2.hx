package math;

class Vec2 {
    // Publics
    public var x:Float = 0;
    public var y:Float = 0;
    public var length (get, set):Float;
    public var lengthsq (get, never):Float;

    public function new( x:Float = 0, y:Float = 0) {
        this.x = x;
        this.y = y;
    } 

    public inline function clone():Vec2 {
        return new Vec2(x, y);
    } 

    public function normalize():Vec2 {
        if(length == 0){
            x = 1;
            return this;
        }

        var len:Float = length;
            x /= len;
            y /= len;
        return this;
    }

    public function truncate(max:Float):Vec2 {
        length = Math.min(max, length);
        return this;

    }

    public function invert():Vec2 {
        x = -x;
        y = -y;
        return this;
    }

    public function dot(other:Vec2):Float {
        return x * other.x + y * other.y;
    } 

    public function cross(other:Vec2):Float {
        return x * other.y - y * other.x;
    }
    
    public function add(other:Vec2):Vec2 {
        x += other.x;
        y += other.y;
        return this;
    }

    public function subtract(other:Vec2):Vec2 {
        x -= other.x;
        y -= other.y;
        return this;
    }

    inline function set_length(value:Float):Float {
        var ep:Float = 0.00000001;
        var _angle:Float = Math.atan2(y, x);

        x = Math.cos(_angle) * value;
        y = Math.sin(_angle) * value;

        if(Math.abs(x) < ep) x = 0;
        if(Math.abs(y) < ep) y = 0;

        return value;

    } 

    inline function get_length():Float return Math.sqrt(lengthsq);
    inline function get_lengthsq():Float return x * x + y * y;
} 
