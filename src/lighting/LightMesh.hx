package lighting;

import DisplayObject;
import ProgramInfo;
import Renderer;
import data.Vertices;
import GL;
import math.Matrix;
import lighting.Visibility.Point;

/**
 * A DisplayObject that renders the visible-area polygon produced by a
 * Visibility sweep as a filled triangle mesh.
 *
 * Vertex layout (light.vert / light.frag):
 *   location 0 → vec3  aPosition  (x, y, 0)
 *
 * Uniforms set each frame in render():
 *   uMatrix    – mat4   view-projection (set by base class)
 *   uLightPos  – vec2   world-space light centre (for radial attenuation)
 *   uRadius    – float  falloff distance in world units
 *   uColor     – vec4   light colour + base intensity
 *
 * Blending: additive (src = SRC_ALPHA, dst = ONE) so multiple lights
 * accumulate brightness.  Use SRC_ALPHA / ONE_MINUS_SRC_ALPHA instead if
 * you want a transparency-style overlay.
 */
class LightMesh extends DisplayObject {

    public var lightX:Float     = 0.0;
    public var lightY:Float     = 0.0;
    public var lightRadius:Float = 200.0;
    public var colorR:Float     = 1.0;
    public var colorG:Float     = 0.9;
    public var colorB:Float     = 0.7;
    public var colorA:Float     = 0.85;

    public function new(renderer:Renderer, programInfo:ProgramInfo) {
        super(renderer, programInfo, new Vertices([]));

        mode = GL.TRIANGLES;
        // Additive blend: GL_SRC_ALPHA=770, GL_ONE=1
        blendFactors = { source: GL.SRC_ALPHA, destination: 1 };
        depthTest  = false;
        depthWrite = false;
    }

    /**
     * Rebuild the vertex buffer from the latest Visibility output.
     * Only positions are stored; colour and radius are pushed as uniforms in render().
     *
     * @param center  Light-source world position (Visibility.center).
     * @param output  Visibility.output – consecutive [pBegin, pEnd] pairs;
     *                each pair + center forms one visible triangle slice.
     */
    public function rebuild(center:Point, output:Array<Point>):Void {
        vertices           = new Vertices([]);
        __verticesToRender = 0;

        lightX = center.x;
        lightY = center.y;

        var cx = center.x;
        var cy = center.y;

        var i = 0;
        while (i < output.length - 1) {
            pushVert(cx,            cy           );
            pushVert(output[i].x,   output[i].y  );
            pushVert(output[i+1].x, output[i+1].y);
            __verticesToRender += 3;
            i += 2;
        }

        needsBufferUpdate = true;
    }

    /** Called by the renderer before each draw; sets light-specific uniforms. */
    override public function render(cameraMatrix:Matrix):Void {
        super.render(cameraMatrix); // sets uMatrix
        uniforms.set("uLightPos", [lightX, lightY]);
        uniforms.set("uRadius",   lightRadius);
        uniforms.set("uColor",    [colorR, colorG, colorB, colorA]);
    }

    private inline function pushVert(x:Float, y:Float):Void {
        vertices.push(x);
        vertices.push(y);
        vertices.push(0.0);
    }
}

