package states;

import display.TileBatch;
import display.ParticleEmitter;
import entity.DisplayEntity;

/**
 * ParticleState
 *
 * Test bed for the ParticleEmitter + TileBatch pipeline.
 *
 * Controls:
 *   LMB  (hold)  — continuous burst at mouse cursor position (point)
 *   RMB  (hold)  — continuous burst spread over a 150×150 area around cursor
 *   SPACE (tap)  — emit a burst at the screen centre
 *   SPACE (hold) — continuous burst every EMIT_INTERVAL seconds
 *   G            — toggle gravity
 *   C / arrows   — standard camera debug (inherited from State)
 */
class ParticleState extends State {

    // How many particles to emit per burst
    private static inline var BURST_COUNT:Int    = 30;
    // Minimum time between continuous bursts while SPACE is held (seconds)
    private static inline var EMIT_INTERVAL:Float = 0.05;

    // SDL mouse button indices
    private static inline var MOUSE_LEFT:Int  = 1;
    private static inline var MOUSE_RIGHT:Int = 3;

    // Bounds-emit area size (world units)
    private static inline var BOUNDS_SIZE:Float = 150.0;

    private var emitter:ParticleEmitter;
    private var particleRegion:Int;
    private var emitCooldown:Float      = 0.0;
    private var mouseEmitCooldown:Float = 0.0;
    private var rmbEmitCooldown:Float   = 0.0;
    private var gravityEnabled:Bool     = true;

    public function new(app:App) {
        super("Particles", app);
    }

    // -------------------------------------------------------------------------
    //  Init
    // -------------------------------------------------------------------------

    override public function init():Void {
        super.init();

        var renderer = app.renderer;

        // -- Shader -----------------------------------------------------------
        var vert    = app.resources.getText("shaders/textured.vert");
        var frag    = app.resources.getText("shaders/textured.frag");
        var program = renderer.createProgramInfo("textured", vert, frag);

        // -- Texture ----------------------------------------------------------
        var texData = app.resources.getTexture("textures/dev1.tga");
        var texture = renderer.uploadTexture(texData);

        // -- TileBatch --------------------------------------------------------
        var batch = new TileBatch(renderer, program, texture);

        // Define a 16×16 particle region from the top-left of the atlas.
        // Tweak the pixel coordinates if you want a different sprite.
        particleRegion = batch.defineRegion(0, 0, 16, 16);

        // -- Emitter ----------------------------------------------------------
        emitter = new ParticleEmitter(batch, 512);
        emitter.gravity = 200.0; // world units / sec² (downward)

        // Wrap the TileBatch in a DisplayEntity so State.render() handles it
        // automatically — no render() override required.
        addEntity(new DisplayEntity(batch, "particle_batch"));

        trace("ParticleState: initialized");
    }

    // -------------------------------------------------------------------------
    //  Update
    // -------------------------------------------------------------------------

    override public function update(dt:Float):Void {
        super.update(dt); // entity updates + camera debug keys

        var cx = app.window.size.x * 0.5;
        var cy = app.window.size.y * 0.5;

        // Continuous burst at mouse cursor while LMB is held (point)
        mouseEmitCooldown -= dt;
        if (app.input.mouse.check(MOUSE_LEFT) && mouseEmitCooldown <= 0.0) {
            mouseEmitCooldown = EMIT_INTERVAL;
            emitter.boundsWidth  = 0.0;
            emitter.boundsHeight = 0.0;
            emitBurst(app.input.mouse.x, app.input.mouse.y);
        }

        // Continuous burst spread across a bounded area while RMB is held
        rmbEmitCooldown -= dt;
        if (app.input.mouse.check(MOUSE_RIGHT) && rmbEmitCooldown <= 0.0) {
            rmbEmitCooldown = EMIT_INTERVAL;
            emitter.boundsWidth  = BOUNDS_SIZE;
            emitter.boundsHeight = BOUNDS_SIZE;
            emitBurst(app.input.mouse.x - BOUNDS_SIZE * 0.5,
                      app.input.mouse.y - BOUNDS_SIZE * 0.5);
        }

        // One burst on tap
        if (app.input.keyboard.pressed(Keycode.SPACE)) {
            emitBurst(cx, cy);
        }

        // Continuous bursts while held
        emitCooldown -= dt;
        if (app.input.keyboard.check(Keycode.SPACE) && emitCooldown <= 0.0) {
            emitCooldown = EMIT_INTERVAL;
            emitBurst(cx, cy);
        }

        // Toggle gravity
        if (app.input.keyboard.released(Keycode.G)) {
            gravityEnabled = !gravityEnabled;
            emitter.gravity = gravityEnabled ? 200.0 : 0.0;
            trace("ParticleState: gravity " + (gravityEnabled ? "ON" : "OFF"));
        }

        // Clear all particles
        if (app.input.keyboard.released(Keycode.X)) {
            emitter.clear();
            trace("ParticleState: particles cleared");
        }

        // Advance physics + build tile geometry for this frame
        emitter.update(dt);
    }

    // -------------------------------------------------------------------------
    //  Helpers
    // -------------------------------------------------------------------------

    private function emitBurst(cx:Float, cy:Float):Void {
        for (i in 0...BURST_COUNT) {
            var angle = Math.random() * Math.PI * 2.0;
            var speed = 60.0 + Math.random() * 200.0;
            var life  = 0.5 + Math.random() * 2.0;

            emitter.emit(
                cx - 8.0, cy - 8.0,      // origin (centred on cursor)
                Math.cos(angle) * speed,   // vx
                Math.sin(angle) * speed,   // vy
                life,
                particleRegion,
                16.0, 16.0
            );
        }
    }
}
