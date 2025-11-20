# TileBatch Improvements Roadmap

## CRITICAL FLAWS (Must Fix - Will cause bugs/crashes)

### 1. PARTIAL UPDATE BROKEN - Dirty Tiles Accumulate Duplicates
**Problem:** Calling `updateTilePosition(5, x, y)` 100 times adds tile ID 5 to `__dirtyTiles` 100 times. Partial update regenerates the same tile's vertices 100 times.

**Current:**
```haxe
__dirtyTiles.push(tileId);  // Called EVERY time - creates duplicates
```

**Expected:** O(k) where k = unique dirty tiles  
**Actual:** O(n) where n = total update calls (worse than full rebuild!)

**Fix:** Use dirty flag array to prevent duplicates
```haxe
private var __isDirty:Array<Bool> = [];  // Fast lookup: is this tile dirty?

public function updateTilePosition(...) {
    if (!__isDirty[tileId]) {
        __isDirty[tileId] = true;
        __dirtyTiles.push(tileId);
    }
}

// Clear in updatePartialBuffers():
for (tileId in __dirtyTiles) {
    __isDirty[tileId] = false;
}
__dirtyTiles = [];
```

---

### 2. PARTIAL UPDATE CREATES TEMP ARRAYS - Defeats "Zero Allocation"
**Problem:** Creating temporary array for EVERY dirty tile defeats the optimization.

**Current:**
```haxe
var tempCache:Array<Float32> = [];  // NEW ALLOCATION EVERY DIRTY TILE
__vertexCache = tempCache;
generateTileVertices(tile);
```

**Impact:** 10 dirty tiles = 10 allocations per frame

**Fix:** Write directly at offset without temp arrays
```haxe
private inline function generateTileVerticesAt(tile:Tile, offset:Int):Void {
    var region = atlasRegions[tile.regionId];
    if (region == null) return;
    
    var v1 = region.v2;
    var v2 = region.v1;
    var x = tile.x + tile.offsetX;
    var y = tile.y + tile.offsetY;
    var w = tile.width;
    var h = tile.height;
    
    // Write all 20 floats directly at offset
    __vertexCache[offset + 0] = x;
    __vertexCache[offset + 1] = y + h;
    __vertexCache[offset + 2] = 0.0;
    __vertexCache[offset + 3] = region.u1;
    __vertexCache[offset + 4] = v1;
    
    __vertexCache[offset + 5] = x + w;
    __vertexCache[offset + 6] = y + h;
    __vertexCache[offset + 7] = 0.0;
    __vertexCache[offset + 8] = region.u2;
    __vertexCache[offset + 9] = v1;
    
    __vertexCache[offset + 10] = x + w;
    __vertexCache[offset + 11] = y;
    __vertexCache[offset + 12] = 0.0;
    __vertexCache[offset + 13] = region.u2;
    __vertexCache[offset + 14] = v2;
    
    __vertexCache[offset + 15] = x;
    __vertexCache[offset + 16] = y;
    __vertexCache[offset + 17] = 0.0;
    __vertexCache[offset + 18] = region.u1;
    __vertexCache[offset + 19] = v2;
}

// Usage in updatePartialBuffers():
generateTileVerticesAt(tile, vertexOffset);
```

---

### 3. __maxTiles DECLARED BUT NEVER USED - Dead Code
**Problem:** Comment says "Preallocate capacity" but nothing is pre-allocated. Arrays still grow dynamically.

**Current:**
```haxe
private var __maxTiles:Int = 1000; // Preallocate capacity ← LIE
```

**Fix:** Either use it or remove it. Don't mislead.

**Option A - Remove:**
```haxe
// Delete the field entirely
```

**Option B - Actually use it:**
```haxe
public function new(programInfo:ProgramInfo, texture:Texture, maxTiles:Int = 1000) {
    this.__maxTiles = maxTiles;
    
    // Pre-allocate arrays
    __vertexCache = [for (i in 0...(maxTiles * 20)) 0.0];
    __indexCache = [for (i in 0...(maxTiles * 6)) 0];
    __tileVertexOffsets = [for (i in 0...maxTiles) -1];
    __isDirty = [for (i in 0...maxTiles) false];
    
    // ... rest of constructor
}
```

---

### 4. NO BOUNDS CHECKING ON VERTEX OFFSET WRITES
**Problem:** If buffer shrinks (tiles removed) but `__tileVertexOffsets` points to old positions, writing past array bounds = CRASH.

**Current:**
```haxe
var vertexOffset = __tileVertexOffsets[tileId];
if (vertexOffset < 0) continue;  // Only checks negative
originalCache[vertexOffset + i] = tempCache[i];  // Can write past bounds
```

**Fix:** Validate offset is within buffer range
```haxe
var vertexOffset = __tileVertexOffsets[tileId];
if (vertexOffset < 0 || vertexOffset + 20 > __vertexCache.length) {
    continue;  // Skip invalid offset
}
```

---

### 5. REDUNDANT VERTICES/INDICES OBJECT CREATION EVERY UPDATE
**Problem:** Creating new wrapper objects every frame allocates memory unnecessarily.

**Current:**
```haxe
this.vertices = new Vertices(__vertexCache);  // NEW OBJECT every update
this.indices = new Indices(__indexCache);     // NEW OBJECT every update
```

**Fix:** Update existing objects' internal data instead
```haxe
// Check if Vertices/Indices classes support updating internal buffer
// If not, may need to modify those classes or accept the overhead
```

---

### 6. V-COORDINATE FLIP HAPPENS EVERY FRAME - Should Be Once
**Problem:** V-coordinate swap happens for EVERY tile EVERY frame during vertex generation. Should be done ONCE when defining region.

**Current (in generateTileVertices):**
```haxe
var v1 = region.v2;  // Swap EVERY render
var v2 = region.v1;  // Swap EVERY render
```

**Fix:** Move to defineRegion()
```haxe
public function defineRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
    // ...
    
    // Store V coordinates already flipped
    region.u1 = atlasX / atlasTexture.width;
    region.v1 = (atlasY + atlasHeight) / atlasTexture.height;  // Flipped
    region.u2 = (atlasX + atlasWidth) / atlasTexture.width;
    region.v2 = atlasY / atlasTexture.height;                  // Flipped
    
    // ...
}

// Then in generateTileVertices, just use directly:
__vertexCache.push(region.v1);  // No swap needed
```

---

## PERFORMANCE ISSUES (Will hurt at scale)

### 7. Tile.offsetX AND offsetY ARE REDUNDANT
**Problem:** Storing both `x` and `offsetX` wastes memory. Just store final position.

**Current:**
```haxe
public var x:Float = 0.0;
public var offsetX:Float = 0.0;  // ← Redundant
public var offsetY:Float = 0.0;  // ← Redundant

// Usage:
var x = tile.x + tile.offsetX;
```

**Waste:** 16 bytes per tile × 10,000 tiles = 160KB

**Fix:** Remove offset fields, just use x/y
```haxe
// In Tile.hx - DELETE:
// public var offsetX:Float = 0.0;
// public var offsetY:Float = 0.0;

// In generateTileVertices:
var x = tile.x;
var y = tile.y;
```

---

### 8. Tile.parent REFERENCE UNUSED - Creates Circular Dependency
**Problem:** Parent reference never read anywhere. Wastes 8 bytes per tile, creates circular reference.

**Current:**
```haxe
public var parent:TileBatch;  // NEVER USED
```

**Waste:** 8 bytes per tile × 10,000 tiles = 80KB

**Fix:** Delete it
```haxe
// In Tile.hx - DELETE:
// public var parent:TileBatch;

// In Tile constructor:
public function new(regionId:Int = 0) {  // Remove parent param
    this.regionId = regionId;
}

// In TileBatch.addTile():
var tile = new Tile();  // Don't pass 'this'
```

---

## MISSING CRITICAL FEATURES

### 9. NO COLOR TINTING SUPPORT
**Problem:** Can't tint individual tiles. Every modern batching system supports per-tile RGBA.

**Use cases:**
- Damage flash (red tint)
- Selection highlight (blue tint)
- Fade out (alpha reduction)
- Team colors

**Implementation:**
```haxe
// In Tile.hx:
public var r:Float = 1.0;  // Red channel multiplier
public var g:Float = 1.0;  // Green channel multiplier
public var b:Float = 1.0;  // Blue channel multiplier
public var a:Float = 1.0;  // Alpha channel multiplier

// In generateTileVertices - expand to 9 floats per vertex:
// x, y, z, u, v, r, g, b, a
__vertexCache[offset + 5] = tile.r;
__vertexCache[offset + 6] = tile.g;
__vertexCache[offset + 7] = tile.b;
__vertexCache[offset + 8] = tile.a;

// Update shader to use vertex colors
// Update vertex stride: 5 → 9 floats per vertex
// Update __verticesToRender calculation: / 9 instead of / 5
```

---

### 10. NO ROTATION SUPPORT
**Problem:** Can't rotate individual tiles. Basic sprite batch functionality.

**Use cases:**
- Rotating projectiles
- Spinning coins
- Directional indicators
- Rotating UI elements

**Implementation:**
```haxe
// In Tile.hx:
public var rotation:Float = 0.0;  // Angle in radians

// In generateTileVertices - apply rotation matrix:
if (tile.rotation != 0.0) {
    var cos = Math.cos(tile.rotation);
    var sin = Math.sin(tile.rotation);
    var cx = x + w * 0.5;  // Center X
    var cy = y + h * 0.5;  // Center Y
    
    // Rotate each vertex around center
    // (px, py) = rotated point
    // px = cx + (vx - cx) * cos - (vy - cy) * sin
    // py = cy + (vx - cx) * sin + (vy - cy) * cos
}
```

---

### 11. NO Z-ORDER/DEPTH SORTING
**Problem:** All tiles render in array order. Can't control draw order for overlapping tiles.

**Use cases:**
- Ground layer (z=0)
- Objects layer (z=1)
- Effects layer (z=2)
- UI layer (z=3)

**Implementation:**
```haxe
// In Tile.hx:
public var z:Float = 0.0;  // Depth/layer

// In generateMesh - sort tiles by Z before generating:
var sortedTiles:Array<{id:Int, tile:Tile}> = [];
for (i in 0...tiles.length) {
    if (tiles[i] != null && tiles[i].visible) {
        sortedTiles.push({id: i, tile: tiles[i]});
    }
}
sortedTiles.sort((a, b) -> {
    if (a.tile.z < b.tile.z) return -1;
    if (a.tile.z > b.tile.z) return 1;
    return 0;
});

// Generate vertices in sorted order
```

---

### 12. NO FRUSTUM CULLING
**Problem:** Rendering ALL tiles even if off-screen. Wastes GPU bandwidth.

**Impact:** 1000×1000 tile map = 1,000,000 tiles sent to GPU when only ~1000 visible.

**Implementation:**
```haxe
// In generateMesh - skip tiles outside camera view:
private function isTileVisible(tile:Tile, cameraX:Float, cameraY:Float, 
                               viewWidth:Float, viewHeight:Float):Bool {
    return tile.x + tile.width >= cameraX &&
           tile.x <= cameraX + viewWidth &&
           tile.y + tile.height >= cameraY &&
           tile.y <= cameraY + viewHeight;
}

// In generateMesh:
if (!isTileVisible(tile, camera.x, camera.y, camera.width, camera.height)) {
    continue;  // Skip off-screen tile
}
```

---

### 13. ARRAY COMPACTION NEVER HAPPENS - Sparse Array Grows Forever
**Problem:** Removing tiles creates null holes. Array length never shrinks. Still iterate through all slots.

**Current:**
```haxe
tiles[tileId] = null;  // Creates hole
__freeTileIds.push(tileId);
// tiles.length = 1000 (even if only 500 are non-null)
```

**Impact:** 50% wasted iteration after removing half the tiles.

**Fix Option A - Periodic compaction:**
```haxe
public function compact():Void {
    var newTiles:Array<Tile> = [];
    var oldToNewId:Map<Int, Int> = new Map();
    
    for (i in 0...tiles.length) {
        if (tiles[i] != null) {
            var newId = newTiles.length;
            oldToNewId.set(i, newId);
            newTiles.push(tiles[i]);
        }
    }
    
    tiles = newTiles;
    __freeTileIds = [];
    __bufferDirty = true;
}
```

**Fix Option B - Auto-compact threshold:**
```haxe
// In removeTile:
if (__freeTileIds.length > tiles.length * 0.5) {
    compact();  // Auto-compact when >50% holes
}
```

---

## IMPLEMENTATION PRIORITY

### Phase 1 - Critical Fixes (Do First)
1. ✅ Fix duplicate dirty tiles (dirty flag array)
2. ✅ Fix temp array allocations (direct offset writes)
3. ✅ Fix V-flip to happen once (move to defineRegion)
4. ✅ Add bounds checking on offset writes
5. ✅ Remove dead code (__maxTiles or implement it)

### Phase 2 - Performance Optimization
6. ✅ Remove Tile.offsetX/offsetY
7. ✅ Remove Tile.parent
8. ✅ Fix redundant Vertices/Indices creation

### Phase 3 - Essential Features
9. ✅ Add color tinting (RGBA per tile)
10. ✅ Add rotation support
11. ✅ Add frustum culling

### Phase 4 - Advanced Features
12. ✅ Add Z-order sorting
13. ✅ Implement array compaction
14. ✅ Pre-allocate buffers properly

---

## CURRENT GRADE: C
**After Phase 1:** B  
**After Phase 2:** A-  
**After Phase 3:** A  
**After Phase 4:** A+ (Production-ready)
