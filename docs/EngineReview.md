# Engine Architecture Review - Brutal Assessment

**Date:** November 16, 2025  
**Reviewer:** Ruthless Mentor Mode  
**Verdict:** 60% Good, 40% Amateur Mistakes

---

## Executive Summary

Your SDL3 + OpenGL 3.3 Core engine written in Haxe (compiling to C++) has a **solid foundation** but suffers from **critical architectural flaws** that will cause performance and maintainability problems as the project scales.

**DO NOT REWRITE IN C++.** Your bottlenecks are architectural, not language-related. Fix the design issues first.

---

## What You Got Right (Don't Get Cocky)

### 1. Modern OpenGL Usage
- **VAO/VBO/EBO architecture** is correct
- **VAO sharing per ProgramInfo** shows you understand state management
- Using OpenGL 3.3 Core properly (no deprecated fixed pipeline)
- Proper attribute pointer setup during VAO creation

**Code Evidence:**
```haxe
// ProgramInfo.hx - VAO owned by shader program
public var vao:GlUInt = 0;

// Renderer.hx - Correct VAO binding for rendering
GL.bindVertexArray(displayObject.programInfo.vao);
GL.bindVertexBuffer(0, displayObject.vbo, 0, displayObject.programInfo.dataPerVertex);
```

### 2. Shader Introspection
- Auto-discovering uniforms and attributes instead of hardcoding
- Pre-computed uniform setters for O(1) lookup (no switch/case in render loop)
- Proper separation of shader compilation from usage

**Code Evidence:**
```haxe
// ProgramInfo.hx
private var uniformMap:Map<String, Uniform> = new Map<String, Uniform>();

public function getUniform(name:String):Uniform {
    return uniformMap.get(name); // O(1) lookup
}
```

### 3. Partial Buffer Updates
- Implemented `bufferSubData` for dynamic content updates
- Avoids full buffer reuploads for small changes
- Shows performance awareness

**Code Evidence:**
```haxe
// Renderer.hx
public function uploadVertexDataPartial(vbo:UInt, offsetInFloats:Int, vertices:Array<Float>):Void {
    GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
    var byteOffset = offsetInFloats * 4;
    GL.bufferSubFloatArray(GL.ARRAY_BUFFER, byteOffset, vertices, vertices.length);
    GL.bindBuffer(GL.ARRAY_BUFFER, 0);
}
```

### 4. Component-Entity Pattern
- Clean separation of logic (Entity/Component) from rendering (DisplayObject)
- Component system allows modular functionality
- Entities can have multiple components

**Code Evidence:**
```haxe
// Entity.hx
private var components:Array<Component> = [];
private var componentMap:Map<String, Component> = new Map();

public function addComponent<T:Component>(component:T):T {
    // ... proper component management
}
```

---

## Where You Screwed Up (The Trash)

### 1. ❌ `trace()` Everywhere Instead of Proper Logging

**Problem:**
Your renderer and core classes use `trace()` calls everywhere because they can't access the `Log` class due to circular dependencies.

**Evidence:**
```haxe
// Renderer.hx - Lines scattered throughout
trace("Created and registered ProgramInfo: " + name);
trace("Error: ProgramInfo '" + name + "' not found!");
trace("Vertex shader compiled successfully");
```

**Why It's Trash:**
- No log levels (info, warn, error, debug)
- Can't disable logging in production
- No log file output
- Can't filter by category
- Makes debugging harder, not easier

**Fix:**
Inject a logging interface or callback into `Renderer` during construction:

```haxe
// Renderer.hx
private var __logCallback:Null<(level:Int, category:Int, message:String)->Void> = null;

public function new(app:App, windowWidth:Int, windowHeight:Int) {
    this.__app = app;
    this.windowWidth = windowWidth;
    this.windowHeight = windowHeight;
    
    // Optional logging - works standalone or with App
    if (app != null && app.log != null) {
        __logCallback = (level, category, message) -> {
            app.log.write(level, category, message);
        };
    }
}

// Then replace all trace() calls with:
private function log(level:Int, category:Int, message:String):Void {
    if (__logCallback != null) {
        __logCallback(level, category, message);
    } else {
        trace(message); // Fallback for standalone use
    }
}
```

---

### 2. ❌ State Management is a Mess

**Problem:**
Your `App.hx` loads assets in `preload()` but doesn't activate any state by default.

**Evidence:**
```haxe
// App.hx - preload() method
public function preload() {
    // ... loads all assets ...
    
    // Then these commented-out lines:
    // var logTestState = new states.LogTestState(this);
    // addState(logTestState);
}
```

**Why It's Trash:**
- Engine boots up and does nothing
- Relies on manual state activation somewhere else (unclear where)
- No default state to fall back on
- Hard to onboard new developers who don't know the startup sequence

**Fix:**
```haxe
// App.hx
public function preload() {
    // ... load assets ...
    
    // ALWAYS have a default state
    var defaultState = new states.UITestState(this);
    addState(defaultState);
    switchToState(defaultState);
}

// OR create a boot state that transitions to menu/game
public function preload() {
    // ... load assets ...
    
    var bootState = new states.BootState(this);
    addState(bootState);
    switchToState(bootState);
    
    // BootState can then transition to MainMenu or whatever
}
```

---

### 3. ❌ Entity-Component System is Incomplete

**Problem:**
Your `Entity` class has components, but they can't communicate properly.

**Missing Features:**
- No component messaging/event system
- No component priorities or execution order control
- Components can't easily query other components
- No way for components to react to entity state changes

**Current State:**
```haxe
// Entity.hx
public function update(deltaTime:Float):Void {
    for (component in components) {
        if (component.active) {
            component.update(deltaTime);
        }
    }
}
// ^ Components update in undefined order
// ^ No way to send messages between components
// ^ No lifecycle events (onAdded, onRemoved, onEnabled)
```

**Fix:**
```haxe
// Component.hx - Add lifecycle hooks
public function onAdded():Void { }  // Called when added to entity
public function onRemoved():Void { }  // Called when removed
public function onEnabled():Void { }  // Called when enabled
public function onDisabled():Void { }  // Called when disabled

// Entity.hx - Component communication
public function sendMessage(message:String, data:Dynamic = null):Void {
    for (component in components) {
        if (component.active) {
            component.receiveMessage(message, data);
        }
    }
}

// Component.hx
public function receiveMessage(message:String, data:Dynamic):Void {
    // Override in subclasses to handle messages
}

// Entity.hx - Execution order
private var componentsByPriority:Array<Component> = [];

public function addComponent<T:Component>(component:T, priority:Int = 0):T {
    components.push(component);
    componentMap.set(component.name, component);
    component.entity = this;
    component.priority = priority;
    
    // Sort by priority
    componentsByPriority = components.copy();
    componentsByPriority.sort((a, b) -> a.priority - b.priority);
    
    component.onAdded();
    return component;
}

public function update(deltaTime:Float):Void {
    for (component in componentsByPriority) {
        if (component.active) {
            component.update(deltaTime);
        }
    }
}
```

---

### 4. ❌ No Render Batching Strategy

**Problem:**
Every `DisplayObject` is a separate draw call. No automatic batching.

**Current Performance:**
- 100 sprites = 100 draw calls
- 200 UI elements = 200 draw calls
- GPU sits idle waiting for CPU to submit next draw call

**Evidence:**
```haxe
// Renderer.hx - renderDisplayObject()
private function renderDisplayObject(displayObject:DisplayObject):Void {
    // ... bind VAO, set uniforms ...
    GL.drawElements(GL.TRIANGLES, displayObject.indexCount, GL.UNSIGNED_INT, 0);
    // ^ ONE draw call per object, even if they share shader+texture
}
```

**Why It's Trash:**
- Modern GPUs can render 10,000+ triangles per draw call efficiently
- Your 100 draw calls are CPU-bound, not GPU-bound
- State changes (bind texture, bind VAO) dominate frame time
- Will tank performance with 200+ objects on screen

**Fix - Automatic Batching:**
```haxe
// Renderer.hx
private var renderQueue:Array<DisplayObject> = [];

public function render(displayObjects:Array<DisplayObject>):Void {
    // Clear queue
    renderQueue = [];
    
    // Populate queue
    for (obj in displayObjects) {
        if (obj.visible) {
            renderQueue.push(obj);
        }
    }
    
    // Sort by (shader, texture, depth) to minimize state changes
    renderQueue.sort((a, b) -> {
        if (a.programInfo.program != b.programInfo.program) {
            return a.programInfo.program - b.programInfo.program;
        }
        if (a.texture != b.texture) {
            return a.texture - b.texture;
        }
        return Std.int(a.z - b.z);
    });
    
    // Batch consecutive objects with same shader+texture
    var batchStart = 0;
    var currentProgram = renderQueue[0].programInfo;
    var currentTexture = renderQueue[0].texture;
    
    for (i in 1...renderQueue.length) {
        var obj = renderQueue[i];
        
        if (obj.programInfo != currentProgram || obj.texture != currentTexture) {
            // State changed - draw previous batch
            drawBatch(batchStart, i - 1);
            
            // Start new batch
            batchStart = i;
            currentProgram = obj.programInfo;
            currentTexture = obj.texture;
        }
    }
    
    // Draw final batch
    drawBatch(batchStart, renderQueue.length - 1);
}

private function drawBatch(startIdx:Int, endIdx:Int):Void {
    if (startIdx > endIdx) return;
    
    var firstObj = renderQueue[startIdx];
    
    // Bind state once for entire batch
    GL.bindVertexArray(firstObj.programInfo.vao);
    GL.useProgram(firstObj.programInfo.program);
    GL.bindTexture(GL.TEXTURE_2D, firstObj.texture);
    
    // Set common uniforms
    setUniformMatrix4fv(firstObj.programInfo, "projection", camera.getMatrix());
    
    // Draw each object in batch (VAO/texture already bound)
    for (i in startIdx...(endIdx + 1)) {
        var obj = renderQueue[i];
        
        // Only set per-object uniforms (model matrix, color, etc.)
        setPerObjectUniforms(obj);
        
        GL.bindVertexBuffer(0, obj.vbo, 0, obj.programInfo.dataPerVertex);
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, obj.ebo);
        GL.drawElements(GL.TRIANGLES, obj.indexCount, GL.UNSIGNED_INT, 0);
    }
}
```

**Better Fix - Instanced Rendering:**
```haxe
// For objects with same mesh (sprites, UI quads)
// Upload all transforms to a uniform buffer
// Draw all instances in ONE call
GL.drawElementsInstanced(GL.TRIANGLES, indexCount, GL.UNSIGNED_INT, 0, instanceCount);
```

---

### 5. ❌ Memory Management is Non-Existent

**Problem:**
No object pooling despite having a `Pool.hx` class.

**Evidence of Waste:**
```haxe
// Camera.hx - getMatrix() creates new Matrix every frame
public function getMatrix():Matrix {
    if (ortho) {
        return Matrix.createOrthographicProjection(...);  // NEW ALLOCATION
    } else {
        return Matrix.createPerspectiveProjection(...);  // NEW ALLOCATION
    }
}

// Text.hx - setText() recreates tile array every time
public function setText(text:String):Void {
    for (tileId in charTiles) {
        font.removeTile(tileId);
    }
    charTiles = [];  // OLD ARRAY DISCARDED
    
    for (i in 0...text.length) {
        charTiles.push(tileId);  // NEW ALLOCATIONS
    }
}
```

**Why It's Trash:**
- Garbage collector pauses every few seconds
- Frame drops when GC runs during gameplay
- Wastes CPU time allocating/freeing memory
- Easily fixable with pooling

**Fix - Pool Matrices:**
```haxe
// Camera.hx
private var cachedProjectionMatrix:Matrix = new Matrix();
private var matrixDirty:Bool = true;

public function update():Void {
    if (!matrixDirty) return;
    
    if (ortho) {
        Matrix.createOrthographicProjectionInto(cachedProjectionMatrix, ...);
    } else {
        Matrix.createPerspectiveProjectionInto(cachedProjectionMatrix, ...);
    }
    
    matrixDirty = false;
}

public function getMatrix():Matrix {
    return cachedProjectionMatrix;  // NO ALLOCATION
}
```

**Fix - Pool Tile Arrays:**
```haxe
// Use your Pool.hx class
private static var tileIdPool:Pool<Array<Int>> = new Pool(() -> [], (arr) -> {
    arr.resize(0);  // Clear array for reuse
});

public function setText(text:String):Void {
    // Clear and return old array to pool
    if (charTiles != null) {
        for (tileId in charTiles) {
            font.removeTile(tileId);
        }
        tileIdPool.put(charTiles);
    }
    
    // Get array from pool
    charTiles = tileIdPool.get();
    
    // ... populate charTiles ...
}
```

---

### 6. ❌ Camera is Primitive

**Problem:**
Camera works for basic 2D but lacks essential features.

**Missing Features:**
- No viewport management (render to portion of screen)
- No multi-camera support (minimap, split-screen)
- Updates every frame even when nothing changed (wastes CPU)
- No camera shake/effects support

**Current State:**
```haxe
// Camera.hx
public function update():Void {
    // Recalculates matrix EVERY FRAME even if nothing changed
    if (ortho) {
        projection = Matrix.createOrthographicProjection(...);
    }
}
```

**Fix:**
```haxe
// Camera.hx
private var _viewportX:Int = 0;
private var _viewportY:Int = 0;
private var _viewportWidth:Int = 640;
private var _viewportHeight:Int = 480;

public var viewport(get, set):Viewport;

public function setViewport(x:Int, y:Int, width:Int, height:Int):Void {
    _viewportX = x;
    _viewportY = y;
    _viewportWidth = width;
    _viewportHeight = height;
    matrixDirty = true;
}

public function applyViewport():Void {
    GL.viewport(_viewportX, _viewportY, _viewportWidth, _viewportHeight);
}

// Renderer.hx
public function renderWithCamera(camera:Camera, displayObjects:Array<DisplayObject>):Void {
    camera.applyViewport();
    camera.update();  // Only updates if dirty
    
    // ... render objects with camera.getMatrix() ...
}
```

---

### 7. ❌ Post-Processing is Hardcoded

**Problem:**
You have ONE post-process shader. No effect stacking.

**Current Limitation:**
```haxe
// Renderer.hx
public var usePostProcessing:Bool = true;

// Only one effect - bloom OR color grading, not both
```

**Why It's Trash:**
- Want bloom + chromatic aberration + vignette? Rewrite shader.
- Can't toggle effects at runtime
- Can't chain effects (render to texture → apply effect → render to texture → apply next effect)
- 2008-era design

**Fix - Effect Chain:**
```haxe
// PostProcessChain.hx
class PostProcessChain {
    private var effects:Array<PostEffect> = [];
    private var pingPongFBOs:Array<Framebuffer> = [];
    
    public function addEffect(effect:PostEffect):Void {
        effects.push(effect);
    }
    
    public function render(sourceFBO:Framebuffer, targetFBO:Framebuffer):Void {
        if (effects.length == 0) {
            // No effects - blit source to target
            blitFramebuffer(sourceFBO, targetFBO);
            return;
        }
        
        var currentSource = sourceFBO;
        var currentTarget = pingPongFBOs[0];
        
        for (i in 0...effects.length) {
            var effect = effects[i];
            
            // Last effect renders to final target
            if (i == effects.length - 1) {
                currentTarget = targetFBO;
            }
            
            effect.render(currentSource, currentTarget);
            
            // Ping-pong for next effect
            currentSource = currentTarget;
            currentTarget = (currentTarget == pingPongFBOs[0]) 
                ? pingPongFBOs[1] 
                : pingPongFBOs[0];
        }
    }
}

// PostEffect.hx
interface PostEffect {
    public function render(source:Framebuffer, target:Framebuffer):Void;
}

// BloomEffect.hx
class BloomEffect implements PostEffect {
    private var blurShader:ProgramInfo;
    private var thresholdShader:ProgramInfo;
    
    public function render(source:Framebuffer, target:Framebuffer):Void {
        // 1. Extract bright pixels
        // 2. Blur them
        // 3. Composite with original
    }
}
```

---

## Should You Rewrite in C++?

### **Hell No. Here's Why:**

#### 1. Haxe to C++ is Already C++
You're compiling to C++. Your bottlenecks aren't the language, they're **algorithmic**:
- Not batching draw calls → **architectural problem**
- Not pooling objects → **design problem**
- Not sorting render queue → **algorithm problem**

C++ won't fix bad architecture. You'll just have:
- Bad architecture + manual memory management
- Bad architecture + segfaults
- Bad architecture + 30-second compile times

#### 2. SDL3 + OpenGL is Good Tech
- SDL3 is modern, actively maintained, cross-platform
- OpenGL 3.3 Core is widely supported (even on old hardware)
- Your bindings work fine

Don't throw away working tech because of unrelated problems.

#### 3. You Need Iteration Speed
As a solo developer:

**Haxe:**
- 2-5 second compile times
- Cross-compile to other targets (JS, HashLink for debugging)
- Macros for meta-programming
- Null safety (catches bugs at compile time)

**C++:**
- 30-60 second compile times
- Manual memory management (new bugs to hunt)
- Segfaults (good luck debugging those)
- Template errors (enjoy 500-line error messages)

**You'd spend 3x more time fighting the language instead of building features.**

#### 4. Your Performance Problems Aren't Real Yet
You don't have performance problems. You have **potential** performance problems.

Fix them when they become actual problems:
1. Profile your game
2. Find the real bottleneck
3. Fix that specific bottleneck
4. Repeat

Don't optimize prematurely. Don't rewrite prematurely.

---

## What You Should Do Instead

### Priority 1: Fix Logging (1 day)
- Add log callback injection to Renderer
- Replace all `trace()` with proper logging
- Add log levels (DEBUG, INFO, WARN, ERROR)

### Priority 2: Implement Render Batching (3-5 days)
- Sort render queue by shader/texture
- Batch consecutive objects with same state
- Measure draw call reduction (should drop 80-90%)

### Priority 3: Add Object Pooling (2-3 days)
- Pool matrices (biggest win)
- Pool vertex arrays for dynamic content
- Pool frequently spawned entities/components

### Priority 4: Complete ECS (3-4 days)
- Component messaging system
- Execution order control
- Lifecycle hooks (onAdded, onRemoved)
- Integrate EventDispatcher

### Priority 5: Improve Post-Processing (2-3 days)
- Effect chain system
- Runtime effect toggling
- Ping-pong framebuffers for multi-pass

### Priority 6: Add Profiling (1-2 days)
- Frame time tracking
- Update/render split timing
- Draw call counter
- Vertex count
- Memory allocation tracking

---

## Profiling Before Optimizing

**Add this NOW:**

```haxe
// Profiler.hx
class Profiler {
    private var timers:Map<String, Float> = new Map();
    private var counters:Map<String, Int> = new Map();
    
    public function startTimer(name:String):Void {
        timers.set(name, SDL.getTicks() / 1000.0);
    }
    
    public function endTimer(name:String):Float {
        var start = timers.get(name);
        if (start == null) return 0;
        
        var elapsed = (SDL.getTicks() / 1000.0) - start;
        timers.remove(name);
        return elapsed * 1000; // milliseconds
    }
    
    public function incrementCounter(name:String):Void {
        var current = counters.get(name);
        counters.set(name, (current != null ? current : 0) + 1);
    }
    
    public function getCounter(name:String):Int {
        return counters.get(name) ?? 0;
    }
    
    public function resetCounters():Void {
        counters.clear();
    }
}

// App.hx
private var profiler:Profiler = new Profiler();

override function update():Void {
    profiler.startTimer("update");
    
    if (currentState != null) {
        currentState.update(deltaTime);
    }
    
    var updateTime = profiler.endTimer("update");
    trace("Update: " + updateTime + "ms");
}

override function render():Void {
    profiler.startTimer("render");
    profiler.resetCounters();
    
    // ... rendering ...
    
    var renderTime = profiler.endTimer("render");
    var drawCalls = profiler.getCounter("drawCalls");
    
    trace("Render: " + renderTime + "ms, Draw Calls: " + drawCalls);
}
```

**Use it to measure:**
- Update time vs render time
- Draw call count
- Vertex count
- Texture binds
- Shader switches

**Measure what's ACTUALLY slow, not what you THINK is slow.**

---

## The Verdict

### Your Engine: **60% Good, 40% Amateur Mistakes**

**Good:**
- Modern OpenGL usage ✓
- Shader introspection ✓
- Partial buffer updates ✓
- Component system basics ✓

**Trash:**
- No batching ✗
- No pooling ✗
- `trace()` everywhere ✗
- Incomplete ECS ✗
- Primitive camera ✗
- Hardcoded post-processing ✗

**Time to Fix:** 2-3 weeks of focused work

**Time to Rewrite in C++:** 6+ months (and you'd make the same mistakes)

---

## Final Words

You're **80% of the way to a solid 2D engine**. The foundation is good—modern OpenGL, proper VAO usage, component system.

**Don't rewrite. Don't second-guess. Fix what you have.**

Your biggest bottleneck right now is **render batching**. Fix that first. Then add pooling. Then complete the ECS.

**In 2-3 weeks, you'll have a genuinely good engine.**

**In 6 months of C++ rewriting, you'll have nothing but regret and segfaults.**

**Now stop asking for validation and go implement render batching.**

---

## Action Items

- [ ] Add logging injection to Renderer (1 day)
- [ ] Implement render queue sorting and batching (3-5 days)
- [ ] Pool matrices and frequently allocated objects (2-3 days)
- [ ] Complete ECS with messaging and priorities (3-4 days)
- [ ] Add post-processing effect chain (2-3 days)
- [ ] Implement profiling system (1-2 days)

**Total:** ~2-3 weeks

**Then you'll have an engine worth being proud of.**
