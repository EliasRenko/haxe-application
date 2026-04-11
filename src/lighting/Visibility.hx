package lighting;

/** Square occluder fed into the visibility algorithm. x/y = world-space centre, r = half-side length. */
class Block {
    public var x:Float;
    public var y:Float;
    public var r:Float;
    public function new(x:Float, y:Float, r:Float) { this.x = x; this.y = y; this.r = r; }
}

/** A 2D point. */
class Point {
    public var x:Float;
    public var y:Float;
    public function new(x:Float, y:Float) { this.x = x; this.y = y; }
}

/** A segment endpoint annotated with the sweep-algorithm state. */
class EndPoint extends Point {
    public var begin:Bool   = false;
    public var segment:Segment = null;
    public var angle:Float  = 0.0;
}

/** A directed line segment between two EndPoints. */
class Segment {
    public var p1:EndPoint;
    public var p2:EndPoint;
    /** Squared distance from the light to the segment midpoint – used for depth ordering. */
    public var d:Float;
    public function new() { d = 0.0; }
}

/**
 * 2D radial-visibility / shadow-cast algorithm.
 *
 * Based on the algorithm described at https://www.redblobgames.com/articles/visibility/
 * Ported from the reference JS implementation; DLL dependency removed in favour of
 * plain Haxe arrays.
 *
 * Typical usage per frame:
 *   1. (once, on map load)   loadMap(bx, by, bw, bh, blocks, walls)
 *   2. (every frame)         setLightLocation(x, y)
 *   3. (every frame)         sweep()
 *   4. (read result)         output  – pairs [pBegin, pEnd, …]; every pair + `center` = one visible triangle
 */
class Visibility {

    /** All occluder line segments (loaded once). */
    public var segments:Array<Segment>;
    /** All segment endpoints (loaded once). */
    public var endpoints:Array<EndPoint>;
    /** Current light-source position. */
    public var center:Point;

    /**
     * Front-to-back ordered list of segments currently intersected by the sweep ray.
     * Rebuilt on every sweep() call; exposed for debugging.
     */
    public var open:Array<Segment>;

    /**
     * Output after sweep(): pairs of Points [pBegin, pEnd, pBegin, pEnd, …].
     * Each consecutive pair together with `center` forms one visible triangle slice:
     *   triangle = (center, output[i*2], output[i*2+1])
     */
    public var output:Array<Point>;

    public function new() {
        segments  = [];
        endpoints = [];
        open      = [];
        center    = new Point(0.0, 0.0);
        output    = [];
    }

    /**
     * Rebuild occluder segment geometry. Call once after the tile layout is known.
     *
     * rawSegs should contain only boundary-facing edges (see LightingSystem.build)
     * so that adjacent tiles do not produce duplicate interior segments, which
     * would cause light to bleed through shared tile edges.
     *
     * @param bx      World-space left edge of the bounding rectangle.
     * @param by      World-space top  edge of the bounding rectangle.
     * @param bw      Bounding-rectangle width.
     * @param bh      Bounding-rectangle height.
     * @param rawSegs Pre-computed boundary segments (x1,y1 → x2,y2).
     */
    public function loadMap(bx:Float, by:Float, bw:Float, bh:Float,
                            rawSegs:Array<{x1:Float, y1:Float, x2:Float, y2:Float}>):Void {
        segments.resize(0);
        endpoints.resize(0);

        // Outer boundary – keeps the polygon finite even when no segment is hit.
        addSegment(bx,      by,      bx,      by + bh);
        addSegment(bx,      by + bh, bx + bw, by + bh);
        addSegment(bx + bw, by + bh, bx + bw, by     );
        addSegment(bx + bw, by,      bx,      by     );

        for (s in rawSegs) {
            addSegment(s.x1, s.y1, s.x2, s.y2);
        }
    }

    private function addSegment(x1:Float, y1:Float, x2:Float, y2:Float):Void {
        var seg = new Segment();
        var p1  = new EndPoint(0.0, 0.0);
        var p2  = new EndPoint(0.0, 0.0);
        p1.x = x1;  p1.y = y1;  p1.segment = seg;
        p2.x = x2;  p2.y = y2;  p2.segment = seg;
        seg.p1 = p1;
        seg.p2 = p2;
        segments.push(seg);
        endpoints.push(p1);
        endpoints.push(p2);
    }

    /**
     * Update per-segment angle data for the new light position.
     * Must be called before sweep() whenever the light moves.
     */
    public function setLightLocation(x:Float, y:Float):Void {
        center.x = x;
        center.y = y;

        for (seg in segments) {
            var dx = 0.5 * (seg.p1.x + seg.p2.x) - x;
            var dy = 0.5 * (seg.p1.y + seg.p2.y) - y;
            seg.d = dx * dx + dy * dy;

            seg.p1.angle = Math.atan2(seg.p1.y - y, seg.p1.x - x);
            seg.p2.angle = Math.atan2(seg.p2.y - y, seg.p2.x - x);

            var dAngle = seg.p2.angle - seg.p1.angle;
            if (dAngle <= -Math.PI) dAngle += 2 * Math.PI;
            if (dAngle  >  Math.PI) dAngle -= 2 * Math.PI;
            seg.p1.begin = (dAngle > 0.0);
            seg.p2.begin = !seg.p1.begin;
        }
    }

    // ---------------------------------------------------------------------------
    //  Sweep helpers
    // ---------------------------------------------------------------------------

    static private function _endpoint_compare(a:EndPoint, b:EndPoint):Int {
        if (a.angle > b.angle) return  1;
        if (a.angle < b.angle) return -1;
        if (!a.begin &&  b.begin) return  1;
        if ( a.begin && !b.begin) return -1;
        return 0;
    }

    /** Returns true if point p is to the left of segment s (Y-down convention). */
    static inline private function leftOf(s:Segment, p:Point):Bool {
        var cross = (s.p2.x - s.p1.x) * (p.y - s.p1.y)
                  - (s.p2.y - s.p1.y) * (p.x - s.p1.x);
        return cross < 0;
    }

    static private function interpolate(p:Point, q:Point, f:Float):Point {
        return new Point(p.x * (1 - f) + q.x * f, p.y * (1 - f) + q.y * f);
    }

    /**
     * Returns true if segment a is closer to the light than segment b.
     * Not anti-symmetric; only valid for pairs that are on-screen simultaneously.
     */
    private function _segment_in_front_of(a:Segment, b:Segment, relativeTo:Point):Bool {
        var A1 = leftOf(a, interpolate(b.p1, b.p2, 0.01));
        var A2 = leftOf(a, interpolate(b.p2, b.p1, 0.01));
        var A3 = leftOf(a, relativeTo);
        var B1 = leftOf(b, interpolate(a.p1, a.p2, 0.01));
        var B2 = leftOf(b, interpolate(a.p2, a.p1, 0.01));
        var B3 = leftOf(b, relativeTo);

        if (B1 == B2 && B2 != B3) return true;
        if (A1 == A2 && A2 == A3) return true;
        if (A1 == A2 && A2 != A3) return false;
        if (B1 == B2 && B2 == B3) return false;
        // Degenerate intersection – treat a as behind b (safe fallback).
        return false;
    }

    // ---------------------------------------------------------------------------
    //  Main sweep
    // ---------------------------------------------------------------------------

    /**
     * Compute the visible-area polygon from the current light position.
     * Results are written to `output`.
     *
     * @param maxAngle  Stop early at this angle (useful for partial sweeps / fan lights).
     *                  Pass the default 999.0 for a full 360° sweep.
     */
    public function sweep(maxAngle:Float = 999.0):Void {
        output = [];
        endpoints.sort(_endpoint_compare);
        open.resize(0);

        var beginAngle = 0.0;

        // Two-pass sweep: pass 0 builds the initial open set without emitting
        // triangles; pass 1 emits triangles as we encounter segment transitions.
        for (pass in 0...2) {
            for (p in endpoints) {
                if (pass == 1 && p.angle > maxAngle) break;

                var current_old = open.length == 0 ? null : open[0];

                if (p.begin) {
                    // Insert the segment into the open list in front-to-back order.
                    var insertIdx = 0;
                    while (insertIdx < open.length
                           && _segment_in_front_of(p.segment, open[insertIdx], center)) {
                        insertIdx++;
                    }
                    open.insert(insertIdx, p.segment);
                } else {
                    open.remove(p.segment);
                }

                var current_new = open.length == 0 ? null : open[0];
                if (current_old != current_new) {
                    if (pass == 1) addTriangle(beginAngle, p.angle, current_old);
                    beginAngle = p.angle;
                }
            }
        }
    }

    // ---------------------------------------------------------------------------
    //  Triangle emission
    // ---------------------------------------------------------------------------

    public function lineIntersection(p1:Point, p2:Point, p3:Point, p4:Point):Point {
        var s = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x))
              / ((p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y));
        return new Point(p1.x + s * (p2.x - p1.x), p1.y + s * (p2.y - p1.y));
    }

    private function addTriangle(angle1:Float, angle2:Float, segment:Segment):Void {
        var p1:Point = center;
        var p2:Point = new Point(center.x + Math.cos(angle1), center.y + Math.sin(angle1));
        var p3:Point;
        var p4:Point;

        if (segment != null) {
            p3 = new Point(segment.p1.x, segment.p1.y);
            p4 = new Point(segment.p2.x, segment.p2.y);
        } else {
            // Fallback: extend the ray to a large distance.
            p3 = new Point(center.x + Math.cos(angle1) * 500, center.y + Math.sin(angle1) * 500);
            p4 = new Point(center.x + Math.cos(angle2) * 500, center.y + Math.sin(angle2) * 500);
        }

        var pBegin = lineIntersection(p3, p4, p1, p2);
        p2.x = center.x + Math.cos(angle2);
        p2.y = center.y + Math.sin(angle2);
        var pEnd = lineIntersection(p3, p4, p1, p2);

        output.push(pBegin);
        output.push(pEnd);
    }
}
