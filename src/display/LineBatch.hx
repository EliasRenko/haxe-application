package display;

import DisplayObject;
import ProgramInfo;
import Renderer;
import math.Matrix;
import data.Vertices;

/**
 * LineBatch - Batches colored lines for efficient OpenGL debug drawing
 * Inherits from DisplayObject, uses renderer for buffer management
 */
class LineBatch extends DisplayObject {
    public static inline var MAX_LINES:Int = 2048; // Preallocate for up to 2048 lines (4096 vertices)
    public static inline var VERTEX_SIZE:Int = 7; // x, y, z, r, g, b, a

    private var lineCount:Int = 0;
    private var persistent:Bool = false;

    /**
     * Create a new LineBatch
     * @param programInfo Shader program for rendering
     * @param persistent If true, lines persist until cleared
     */
    public function new(programInfo:ProgramInfo, persistent:Bool = false) {
        // Preallocate empty vertices array
        var emptyVertices = new Vertices([]);
        super(programInfo, emptyVertices, null); // No indices, GL_LINES
        mode = 0x0001; // GL.LINES
        this.persistent = persistent;
        this.vertices = [];
        lineCount = 0;
        __verticesToRender = 0;
        active = true;
    }

    /** Add a line to the batch (with color per vertex) */
    public function addLine(x0:Float, y0:Float, z0:Float, x1:Float, y1:Float, z1:Float, color0:Array<Float>, color1:Array<Float>) {
        if (lineCount >= MAX_LINES) return;
        // Vertex 1
        vertices.push(x0); vertices.push(y0); vertices.push(z0);
        vertices.push(color0[0]); vertices.push(color0[1]); vertices.push(color0[2]); vertices.push(color0[3]);
        // Vertex 2
        vertices.push(x1); vertices.push(y1); vertices.push(z1);
        vertices.push(color1[0]); vertices.push(color1[1]); vertices.push(color1[2]); vertices.push(color1[3]);
        lineCount++;
        __verticesToRender += 2;
        needsBufferUpdate = true;
    }

    /** Called by renderer to update GPU buffers */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!active) return;
        renderer.uploadData(this);
        needsBufferUpdate = false;
    }

    /** Set uniforms and prepare for drawing */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible || !active) return;
        trace("LineBatch: === RENDER START ===");
        trace("LineBatch: Lines: " + lineCount + ", Vertices: " + __verticesToRender);
        trace("LineBatch: Mode: " + mode + " (GL_LINES=0x0001)");
        trace("LineBatch: Visible: " + visible + ", Active: " + active);
        trace("LineBatch: Program: " + programInfo.name + " (ID: " + programInfo.programId + ")");
        trace("LineBatch: Shader compiled: " + programInfo.isCompiled);
        
        // Set MVP matrix for line shader
        updateTransform();
        var finalMatrix = Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        uniforms.set("uMatrix", finalMatrix.data);
        
        trace("LineBatch: Calling super.render()...");
        // Call parent to actually draw
        super.render(cameraMatrix);
        
        trace("LineBatch: === RENDER END ===");
        trace("LineBatch: Render complete");
    }

    override public function postRender():Void {
        // Reset for next frame if not persistent
        if (!persistent) {
            lineCount = 0;
            vertices = [];
            __verticesToRender = 0;
            needsBufferUpdate = true;
        }
    }

    /** Clear all batched lines (manual) */
    public function clear() {
        lineCount = 0;
        vertices = [];
        __verticesToRender = 0;
        needsBufferUpdate = true;
    }

    /** Set persistent mode (lines stay until cleared) */
    public function setPersistent(value:Bool) {
        persistent = value;
    }

    public function isPersistent():Bool {
        return persistent;
    }
}
