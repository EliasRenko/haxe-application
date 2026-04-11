package lighting;

import ProgramInfo;
import Renderer;
import App;
import entity.DisplayEntity;
import lighting.Visibility;

/**
 * Manages 2D visibility-based lighting for a tile map.
 *
 * Occluder geometry (tiles) is registered once after map load.  Any number of
 * LightSources can then be created; each receives its own copy of the geometry.
 *
 * Typical setup (inside a State.init or after map load):
 *
 *   lightingSystem = new LightingSystem();
 *   lightingSystem.setBounds(mapX, mapY, mapWidth, mapHeight);
 *
 *   // For every solid tile:
 *   lightingSystem.addTile(cx, cy, tileSize * 0.5);
 *
 *   lightingSystem.build();   // commits geometry to all existing lights
 *
 *   var lineProgramInfo = renderer.createProgramInfo("line", vertSrc, fragSrc);
 *   var light = lightingSystem.addLight(renderer, lineProgramInfo, wx, wy);
 *   addEntity(new DisplayEntity(light.mesh, "light_0"));
 *
 * Every frame:
 *   lightingSystem.update();          // re-sweeps all lights
 *   // (optional) light.x / light.y = newPos;  then update() picks it up
 *
 * Performance note:
 *   Each LightSource owns a full copy of all segment data.  For large maps
 *   consider culling tiles to those within the light's radius before calling
 *   build() / addLight(), or rebuilding segments only when the light moves far
 *   enough that new tiles enter its range.
 */
class LightingSystem {

    /**
     * Tiles stored by their centre key so we can do O(1) neighbour checks
     * when computing boundary edges in build().
     */
    private var _tileMap:Map<String, Block> = new Map();

    /** Boundary segments computed by the last build() call. */
    private var _cachedSegs:Array<{x1:Float, y1:Float, x2:Float, y2:Float}> = [];

    /** All managed lights. */
    private var _lights:Array<LightSource> = [];

    // Map bounding rect (defines the outer visibility boundary).
    private var _bx:Float = 0.0;
    private var _by:Float = 0.0;
    private var _bw:Float = 0.0;
    private var _bh:Float = 0.0;

    public function new() {}

    // -------------------------------------------------------------------------
    //  Geometry setup
    // -------------------------------------------------------------------------

    /**
     * Set the world-space bounding rectangle of the map.
     * Must be called before build().
     */
    public function setBounds(x:Float, y:Float, width:Float, height:Float):Void {
        _bx = x;  _by = y;  _bw = width;  _bh = height;
    }

    /**
     * Register a square tile as a light occluder.
     *
     * @param cx  Tile centre X in world space.
     * @param cy  Tile centre Y in world space.
     * @param r   Tile half-side length (typically tileSize / 2).
     */
    public function addTile(cx:Float, cy:Float, r:Float):Void {
        _tileMap.set(cx + "_" + cy, new Block(cx, cy, r));
    }

    /**
     * Compute boundary-only segments and distribute them to all lights.
     * Call once after all addTile() calls have been made.
     * Safe to call again if the tile layout changes (dynamic tiles).
     *
     * Only edges facing empty space are added; shared interior edges between
     * adjacent tiles are skipped entirely.  This prevents the duplicate-segment
     * ambiguity that causes light to bleed through tile corners/seams.
     */
    public function build():Void {
        _cachedSegs = _computeBoundarySegs();
        for (light in _lights) {
            light.loadOccluders(_cachedSegs, _bx, _by, _bw, _bh);
        }
    }

    private function _computeBoundarySegs():Array<{x1:Float, y1:Float, x2:Float, y2:Float}> {
        var segs:Array<{x1:Float, y1:Float, x2:Float, y2:Float}> = [];
        for (_ => block in _tileMap) {
            var cx = block.x;  var cy = block.y;  var r = block.r;
            var d  = r * 2.0; // distance to neighbour centre
            // Left edge  (no neighbour to the left)
            if (!_tileMap.exists((cx - d) + "_" + cy))
                segs.push({x1: cx-r, y1: cy-r, x2: cx-r, y2: cy+r});
            // Bottom edge (no neighbour below)
            if (!_tileMap.exists(cx + "_" + (cy + d)))
                segs.push({x1: cx-r, y1: cy+r, x2: cx+r, y2: cy+r});
            // Right edge  (no neighbour to the right)
            if (!_tileMap.exists((cx + d) + "_" + cy))
                segs.push({x1: cx+r, y1: cy+r, x2: cx+r, y2: cy-r});
            // Top edge    (no neighbour above)
            if (!_tileMap.exists(cx + "_" + (cy - d)))
                segs.push({x1: cx+r, y1: cy-r, x2: cx-r, y2: cy-r});
        }
        return segs;
    }

    // -------------------------------------------------------------------------
    //  Light management
    // -------------------------------------------------------------------------

    /**
     * Create a new LightSource at the given world position, initialise its GPU
     * mesh, load the current occluder geometry, and return it.
     *
     * The caller must still add the light's mesh to the State:
     *   addEntity(new DisplayEntity(light.mesh, "my_light"));
     *
     * @param renderer     Active Renderer.
     * @param programInfo  ProgramInfo for the `light.vert / light.frag` shaders.
     * @param x/y          Initial world-space position.
     * @param radius       Falloff radius in world units.
     * @param r/g/b/a      Light colour and opacity.
     */
    public function addLight(renderer:Renderer, programInfo:ProgramInfo,
                             x:Float, y:Float, radius:Float = 200.0,
                             r:Float = 1.0, g:Float = 0.9,
                             b:Float = 0.7, a:Float = 0.85):LightSource {
        var light = new LightSource(x, y, radius, r, g, b, a);
        light.init(renderer, programInfo);
        light.loadOccluders(_cachedSegs, _bx, _by, _bw, _bh);
        _lights.push(light);
        return light;
    }

    // -------------------------------------------------------------------------
    //  Per-frame update
    // -------------------------------------------------------------------------

    /**
     * Re-sweep all lights and upload new polygons to their meshes.
     * Call once per frame.
     */
    public function update():Void {
        for (light in _lights) {
            light.update(light.x, light.y);
        }
    }
}
