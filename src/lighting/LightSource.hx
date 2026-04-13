package lighting;

import Renderer;

/**
 * A single 2D light source.
 *
 * Owns a Visibility instance (which holds the occluder segments for this light)
 * and a LightMesh (the renderable polygon).
 *
 * Usage:
 *   var light = new LightSource(wx, wy, radius);
 *   light.init(renderer, lightProgramInfo);
 *   addEntity(new DisplayEntity(light.mesh, "light_0"));
 *
 *   // every frame:
 *   light.update(newX, newY);
 *
 * The occluder geometry must be loaded into the Visibility instance before the
 * first update().  LightingSystem handles this via loadOccluders().
 */
class LightSource {

    /** Current world-space position. */
    public var x:Float;
    public var y:Float;

    /** Falloff radius in world units – attenuation reaches 0 at this distance. */
    public var radius:Float;

    /** RGBA colour of the light cone. */
    public var colorR:Float;
    public var colorG:Float;
    public var colorB:Float;
    public var colorA:Float;

    /**
     * The renderable mesh – wrap in a DisplayEntity and add to the State so it
     * is drawn each frame.  Only valid after init() has been called.
     */
    public var mesh:LightMesh;

    /** Internal visibility instance; geometry is loaded by LightingSystem. */
    private var _visibility:Visibility;

    /**
     * @param x/y    Initial world-space position.
     * @param radius Falloff radius in world units.
     * @param r/g/b  Light colour (default: warm white).
     * @param a      Light opacity / base intensity (0–1).
     */
    public function new(x:Float, y:Float, radius:Float = 200.0,
                        r:Float = 1.0, g:Float = 0.9,
                        b:Float = 0.7, a:Float = 0.85) {
        this.x = x;  this.y = y;  this.radius = radius;
        colorR = r;  colorG = g;  colorB = b;  colorA = a;
        _visibility = new Visibility();
    }

    /**
     * Initialise the GPU-side mesh.  Must be called once before the first
     * update().  `programInfo` must use the `light.vert / light.frag` shaders.
     */
    public function init(renderer:Renderer):Void {
        mesh = new LightMesh(renderer);
        mesh.lightRadius = radius;
        mesh.colorR = colorR;
        mesh.colorG = colorG;
        mesh.colorB = colorB;
        mesh.colorA = colorA;
    }

    /**
     * Load (or reload) pre-computed boundary segments from LightingSystem.
     * Called by LightingSystem – do not call directly.
     */
    public function loadOccluders(rawSegs:Array<{x1:Float, y1:Float, x2:Float, y2:Float}>,
                                  bx:Float, by:Float,
                                  bw:Float, bh:Float):Void {
        _visibility.loadMap(bx, by, bw, bh, rawSegs);
    }

    /**
     * Move the light to (nx, ny), re-sweep visibility, and upload the new
     * polygon to the GPU mesh.  Call every frame (or whenever the light moves).
     */
    public function update(nx:Float, ny:Float):Void {
        x = nx;
        y = ny;
        _visibility.setLightLocation(nx, ny);
        _visibility.sweep();
        if (mesh != null) {
            // Sync mutable properties to the mesh every frame so changes made
            // by the caller (e.g. radius, color) take effect without extra calls.
            mesh.lightRadius = radius;
            mesh.colorR = colorR;  mesh.colorG = colorG;
            mesh.colorB = colorB;  mesh.colorA = colorA;
            mesh.rebuild(_visibility.center, _visibility.output);
        }
    }
}

