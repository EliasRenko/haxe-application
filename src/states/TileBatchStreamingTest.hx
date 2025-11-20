package states;

import State;
import App;
import Renderer;
import display.TileBatchStreaming;
import display.Tile;

/**
 * TileBatchStreamingTest - Test state for ring buffer streaming technique
 * 
 * Features:
 * - 1000 particles with random velocities
 * - All particles move every frame (stress test for ring buffer)
 * - Uses dev_tiles.tga texture atlas
 * - Demonstrates performance benefits of ring buffer for massive updates
 * - FPS counter to monitor performance
 */
class TileBatchStreamingTest extends State {
    
    private var particleBatch:TileBatchStreaming;
    private var particleCount:Int = 1000;
    private var velocities:Array<{vx:Float, vy:Float}> = [];
    
    // Screen bounds for wrapping
    private var screenWidth:Float = 800;
    private var screenHeight:Float = 600;
    
    // FPS tracking
    private var frameCount:Int = 0;
    private var fpsTimer:Float = 0;
    private var currentFPS:Float = 0;
    
    public function new(app:App) {
        super("TileBatchStreamingTest", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("=== TileBatchStreaming Test ===");
        trace("Testing ring buffer with " + particleCount + " particles");
        
        // Setup camera for 2D orthographic view
        camera.ortho = true;
        
        var renderer = app.renderer;
        
        // Create ProgramInfo for textured rendering
        var vertShader = app.resources.getText("shaders/textured.vert");
        var fragShader = app.resources.getText("shaders/textured.frag");
        var programInfo = renderer.createProgramInfo("TileBatchStreaming", vertShader, fragShader);
        
        // Load texture
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("TileBatchStreamingTest: Error - Could not load dev_tiles.tga!");
            return;
        }
        
        var texture = renderer.uploadTexture(textureData);
        trace("TileBatchStreamingTest: Uploaded texture " + texture.width + "x" + texture.height);
        
        // Create streaming batch with 4MB ring buffer
        particleBatch = new TileBatchStreaming(programInfo, texture, particleCount, 4);
        
        // Position at origin
        particleBatch.x = 0;
        particleBatch.y = 0;
        particleBatch.z = 0.0;
        
        // Define particle sprite region (16x16 from center of atlas)
        var particleRegion = particleBatch.defineRegion(32, 32, 16, 16);
        trace("TileBatchStreamingTest: Defined particle region " + particleRegion);
        
        // Spawn particles with random positions and velocities
        trace("TileBatchStreamingTest: Spawning " + particleCount + " particles...");
        for (i in 0...particleCount) {
            var x = Math.random() * screenWidth;
            var y = Math.random() * screenHeight;
            
            // Add particle tile
            var tileId = particleBatch.addTile(x, y, 16, 16, particleRegion);
            
            // Store random velocity
            var speed = 20 + Math.random() * 80; // 20-100 pixels/sec
            var angle = Math.random() * Math.PI * 2;
            velocities.push({
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed
            });
            
            if (i % 200 == 0) {
                trace("  Spawned " + i + " particles...");
            }
        }
        
        trace("TileBatchStreamingTest: Spawned " + particleCount + " particles");
        trace("TileBatchStreamingTest: Tile count = " + particleBatch.getTileCount());
        
        // Mark for initial buffer update
        particleBatch.needsBufferUpdate = true;
        
        trace("TileBatchStreamingTest: Initialization complete");
        trace("Expected behavior:");
        trace("  - All particles should move smoothly");
        trace("  - Watch console for 'Ring buffer wrapped' messages");
        trace("  - Monitor FPS (should stay high even with 1000 updates/frame)");
    }
    
    override public function update(dt:Float):Void {
        super.update(dt);
        
        if (particleBatch == null) return;
        
        // Update FPS counter
        frameCount++;
        fpsTimer += dt;
        if (fpsTimer >= 1.0) {
            currentFPS = frameCount / fpsTimer;
            trace("FPS: " + Std.int(currentFPS) + " | Particles: " + particleCount + " | All moving every frame");
            frameCount = 0;
            fpsTimer = 0;
        }
        
        // Update all particle positions
        for (i in 0...particleBatch.tiles.length) {
            var tile = particleBatch.tiles[i];
            if (tile == null) continue;
            
            var vel = velocities[i];
            
            // Move particle
            tile.x += vel.vx * dt;
            tile.y += vel.vy * dt;
            
            // Wrap around screen edges
            if (tile.x < -16) {
                tile.x = screenWidth;
            } else if (tile.x > screenWidth) {
                tile.x = -16;
            }
            
            if (tile.y < -16) {
                tile.y = screenHeight;
            } else if (tile.y > screenHeight) {
                tile.y = -16;
            }
        }
        
        // Mark for update (ring buffer will stream all particles)
        particleBatch.needsBufferUpdate = true;
    }
    
    override public function render(renderer:Renderer):Void {
        // Render the particle batch
        if (particleBatch != null && particleBatch.visible) {
            renderer.renderDisplayObject(particleBatch, camera.getMatrix());
        }
        
        super.render(renderer);
    }
    
    override public function release():Void {
        trace("TileBatchStreamingTest: Releasing resources");
        
        if (particleBatch != null) {
            particleBatch.clear();
        }
        
        velocities = [];
        
        super.release();
    }
}
