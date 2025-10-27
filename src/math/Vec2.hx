package math;

class Vec2 {

    // Publics
    public var x:Float;
    public var y:Float;

    public function new(x:Float = 0, y:Float = 0) {
        this.x = x;
        this.y = y;
    }

    public function add(v:Vec2):Vec2 {
        return new Vec2(this.x + v.x, this.y + v.y);
    }

    public function subtract(v:Vec2):Vec2 {
        return new Vec2(this.x - v.x, this.y - v.y);
    }

    public function scale(s:Float):Vec2 {
        return new Vec2(this.x * s, this.y * s);
    }

    public function dot(v:Vec2):Float {
        return this.x * v.x + this.y * v.y;
    }

    public function length():Float {
        return Math.sqrt(this.x * this.x + this.y * this.y);
    }

    public function normalize():Vec2 {
        var len = length();
        if (len == 0) return new Vec2(0, 0);
        return new Vec2(this.x / len, this.y / len);
    }
}