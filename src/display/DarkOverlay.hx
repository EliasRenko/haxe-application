package display;

import DisplayObject;
import ProgramInfo;
import Renderer;
import data.Vertices;
import GL;
import math.Matrix;

/**
 * A full-viewport black quad drawn between world tiles and light meshes.
 *
 * Blends over the scene at `ambientDarkness` opacity (0 = invisible, 1 = pitch black).
 * Light meshes drawn on top use additive blending to punch through the darkness.
 *
 * Uses the `line.vert / line.frag` shaders (vec3 aPosition + vec4 aColor).
 *
 * Call rebuild() every frame with the current world-space viewport bounds.
 */
@:shader("line")
class DarkOverlay extends DisplayObject {

    /** Darkness of the ambient layer.  0 = fully transparent, 1 = pitch black. */
    public var ambientDarkness:Float;

    public function new(renderer:Renderer, ambientDarkness:Float = 0.85) {
        // Retrieve the pre-registered "line" shader from the renderer's cache
        // (RunnerState calls renderer.createProgramInfo("line", ...) before this)
        var programInfo:ProgramInfo = renderer.getProgramInfo("line");
        super(programInfo, new Vertices([]));
        this.ambientDarkness = ambientDarkness;
        mode       = GL.TRIANGLES;
        blendFactors = { source: GL.SRC_ALPHA, destination: GL.ONE_MINUS_SRC_ALPHA };
        depthTest  = false;
        depthWrite = false;
    }

    /**
     * Rebuild the quad to cover the given world-space viewport rectangle.
     * Call once per frame in State.update() (before lightingSystem.update()).
     *
     * Computing the visible world rect for an unrotated ortho camera with zoom:
     *   worldLeft   = camera.x
     *   worldTop    = camera.y
     *   worldRight  = camera.x + windowWidth  / camera.zoom
     *   worldBottom = camera.y + windowHeight / camera.zoom
     */
    public function rebuild(worldLeft:Float, worldTop:Float,
                            worldRight:Float, worldBottom:Float):Void {
        vertices           = new Vertices([]);
        __verticesToRender = 0;

        var a = ambientDarkness;

        // Two triangles: TL→TR→BR and TL→BR→BL
        pushVert(worldLeft,  worldTop,    a);
        pushVert(worldRight, worldTop,    a);
        pushVert(worldRight, worldBottom, a);

        pushVert(worldLeft,  worldTop,    a);
        pushVert(worldRight, worldBottom, a);
        pushVert(worldLeft,  worldBottom, a);

        __verticesToRender = 6;
        needsBufferUpdate  = true;
    }

    private inline function pushVert(x:Float, y:Float, a:Float):Void {
        vertices.push(x);
        vertices.push(y);
        vertices.push(0.0);
        // Black colour, variable alpha
        vertices.push(0.0);
        vertices.push(0.0);
        vertices.push(0.0);
        vertices.push(a);
    }
}
