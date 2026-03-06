package display;

import ds.Pool;

/**
 * Per-particle data: physics + the Tile used for rendering.
 * The Tile is reused from the pool across the particle's lifetime.
 */
typedef ParticleData = {
    var tile:    Tile;
    var vx:      Float;
    var vy:      Float;
    var life:    Float;
    var maxLife: Float;
}

/**
 * ParticleEmitter
 *
 * Manages a fixed-size pool of particles, each backed by a Tile in a
 * TileBatch.  Every frame:
 *   1. Call update(dt)  — advances physics and feeds tile geometry into the batch.
 *   2. Let the TileBatch render normally (e.g. via a DisplayEntity).
 *
 * No allocations occur at runtime after construction.
 */
class ParticleEmitter {

    /** The underlying tile batch used for rendering. */
    public var tileBatch:TileBatch;

    /** All currently alive particles. */
    public var particles:Array<ParticleData>;

    /** Number of alive particles. */
    public var count(get, never):Int;

    /** Optional gravity applied to vy every second (world units/sec²). */
    public var gravity:Float = 0.0;

    /** Emission bounds. When > 0, spawn positions are randomised within
        [x, x+boundsWidth] × [y, y+boundsHeight] on every emit() call. */
    public var boundsWidth:Float  = 0.0;
    public var boundsHeight:Float = 0.0;

    private var pool:Pool<ParticleData>;

    // -------------------------------------------------------------------------

    public function new(tileBatch:TileBatch, poolSize:Int = 256) {
        this.tileBatch = tileBatch;
        this.particles = [];
        pool = new Pool<ParticleData>(poolSize, poolSize, createParticle);
    }

    private function createParticle():ParticleData {
        return {
            tile:    new Tile(tileBatch, 0),
            vx:      0.0,
            vy:      0.0,
            life:    0.0,
            maxLife: 0.0
        };
    }

    // -------------------------------------------------------------------------

    /**
     * Emit one particle.
     * @param x         World X origin
     * @param y         World Y origin
     * @param vx        Initial horizontal velocity (world units/sec)
     * @param vy        Initial vertical velocity   (world units/sec)
     * @param life      Lifetime in seconds
     * @param regionId  Atlas region defined on the TileBatch
     * @param width     Tile width  in world units (default 16)
     * @param height    Tile height in world units (default 16)
     */
    public function emit(x:Float, y:Float, vx:Float, vy:Float, life:Float, regionId:Int, width:Float = 16.0, height:Float = 16.0):Void {

        var p = pool.get();
        if (p == null) return; // pool exhausted — silent drop

        // Scatter spawn position within bounds (if set)
        var spawnX = x + (boundsWidth  > 0 ? Math.random() * boundsWidth  : 0.0);
        var spawnY = y + (boundsHeight > 0 ? Math.random() * boundsHeight : 0.0);

        p.tile.x        = spawnX;
        p.tile.y        = spawnY;
        p.tile.width    = width;
        p.tile.height   = height;
        p.tile.regionId = regionId;
        p.tile.visible  = true;
        p.vx      = vx;
        p.vy      = vy;
        p.life    = life;
        p.maxLife = life;

        particles.push(p);
    }

    /**
     * Advance physics and build tile geometry for the current frame.
     * Must be called BEFORE the TileBatch is rendered.
     * @param dt  Delta time in seconds
     */
    public function update(dt:Float):Void {
        var i = particles.length;
        while (i-- > 0) {
            var p = particles[i];

            // Physics
            p.vy     += gravity * dt;
            p.tile.x += p.vx * dt;
            p.tile.y += p.vy * dt;
            p.life   -= dt;

            if (p.life <= 0) {
                // Expire — return to pool
                p.tile.visible = false;
                particles.splice(i, 1);
                pool.put(p);
            } else {
                // Build tile geometry for this frame
                tileBatch.buildTile(p.tile);
            }
        }
    }

    /** Kill every active particle and return them all to the pool. */
    public function clear():Void {
        var i = particles.length;
        while (i-- > 0) {
            var p = particles[i];
            p.tile.visible = false;
            pool.put(p);
        }
        particles = [];
    }

    // -------------------------------------------------------------------------

    private inline function get_count():Int return particles.length;
}
