# TileBatchStreaming - Ring Buffer Implementation

## Overview

`TileBatchStreaming` is a high-performance variant of `TileBatch` that uses the **ring buffer streaming technique** for optimal GPU upload performance. It's designed for scenarios where many tiles update frequently.

## When to Use

### ✅ Use TileBatchStreaming For:

- **Particle Systems**: 1000+ particles updating every frame
- **Dynamic Enemy Batches**: 100+ enemies with frequent movement
- **Animated Sprites**: Multiple sprites with per-frame animation updates
- **Any scenario where >50% of tiles change per frame**

### ❌ Use Standard TileBatch For:

- **Static Tilemaps**: Background tiles that rarely change
- **Sparse Updates**: <10% of tiles dirty per frame
- **Small Batches**: <100 tiles total

## Key Differences from Standard TileBatch

| Feature | TileBatch | TileBatchStreaming |
|---------|-----------|-------------------|
| Upload Method | `glBufferSubData` | `glMapBufferRange` + `memcpy` |
| GPU Sync | Potential stalls | Unsynchronized (no stalls) |
| Buffer Strategy | Fixed size, partial updates | Ring buffer, full re-upload |
| Memory | 78KB + 23KB (1000 tiles) | 4MB default (32,000+ tiles) |
| CPU Overhead | Low | Very low |
| Best For | Sparse updates | Frequent updates |

## Usage Example

```haxe
// Create streaming batch with 4MB ring buffer
var particleSystem = new TileBatchStreaming(
    programInfo,
    atlasTexture,
    2000,  // max 2000 particles
    4      // 4MB ring buffer
);

// Define atlas region for particle sprite
var particleRegion = particleSystem.defineRegion(0, 0, 16, 16);

// Spawn 1000 particles
for (i in 0...1000) {
    var x = Math.random() * 800;
    var y = Math.random() * 600;
    particleSystem.addTile(x, y, 16, 16, particleRegion);
}

// In update loop - move all particles
for (i in 0...particleSystem.tiles.length) {
    var tile = particleSystem.tiles[i];
    if (tile == null) continue;
    
    // Update position
    tile.x += tile.velocityX * dt;
    tile.y += tile.velocityY * dt;
}

// Mark for update (will stream all visible tiles next frame)
particleSystem.needsBufferUpdate = true;
```

## Technical Details

### Ring Buffer Workflow

1. **Initialization**:
   - Allocates 4MB GPU buffer with `glBufferData(NULL)`
   - Creates CPU staging buffer for gathering visible tiles

2. **Every Frame**:
   - Gathers all visible tiles into staging buffer (CPU-side)
   - Calculates required bytes (with 64-byte alignment)
   - Checks if data fits at current cursor position
   - If not, **orphans buffer** (`glBufferData(NULL)`) and resets cursor to 0
   - Maps buffer range with `GL_MAP_UNSYNCHRONIZED_BIT` (no GPU sync!)
   - Uses `memcpy` to copy staging data directly to mapped GPU memory
   - Unmaps buffer
   - Advances cursor for next frame

3. **Rendering**:
   - Uses standard `glDrawElements` with offset from ring buffer position

### Performance Characteristics

**Pros**:
- **No GPU stalls**: Unsynchronized mapping means GPU can keep working
- **Minimal API calls**: 1 map + 1 copy + 1 unmap + 1 draw per frame
- **Scales to thousands**: 4MB buffer holds ~32,000 tiles worth of data
- **Predictable performance**: Consistent frame times even with many updates

**Cons**:
- **Higher memory usage**: 4MB GPU buffer vs 78KB for standard TileBatch
- **Re-uploads everything**: Even if only 1 tile changed, all visible tiles are uploaded
- **Not ideal for sparse updates**: Wastes bandwidth if only few tiles change

### Buffer Size Recommendations

| Use Case | Tiles | Buffer Size | Reasoning |
|----------|-------|-------------|-----------|
| Particle System | 2000-5000 | 4MB | Holds ~16 frames of full updates |
| Enemy Batch | 500-1000 | 2MB | Moderate capacity |
| Massive Particles | 10000+ | 8MB | Large capacity for complex effects |

## Memory Layout

```
Ring Buffer (4MB):
[─────Frame 1 data─────][─────Frame 2 data─────][─────Frame 3 data─────]...
 ↑ cursor = 0           ↑ cursor = 160KB        ↑ cursor = 320KB
 
When cursor + aligned > 4MB:
  glBufferData(NULL) → orphan buffer (GPU keeps old data until done)
  cursor = 0 → wrap around to start
  [─────Frame N data─────]...
   ↑ cursor = 0 (wrapped)
```

## API Reference

### Constructor

```haxe
new(programInfo:ProgramInfo, texture:Texture, maxTiles:Int = 1000, bufferSizeMB:Int = 4)
```

- `maxTiles`: Maximum tiles in batch (affects staging buffer size)
- `bufferSizeMB`: Size of GPU ring buffer in MB (default 4MB)

### Methods

Same as standard `TileBatch`:
- `defineRegion(x, y, w, h)`: Define atlas region
- `addTile(x, y, w, h, regionId)`: Add tile
- `removeTile(tileId)`: Remove tile
- `updateTilePosition(tileId, x, y)`: Update position
- `getTile(tileId)`: Get tile by ID
- `clear()`: Remove all tiles

## Performance Tips

1. **Set appropriate buffer size**: 
   - Too small: Frequent orphaning (overhead)
   - Too large: Wasted GPU memory
   - Sweet spot: Holds 10-20 frames of data

2. **Visibility culling**: 
   - Only generate vertices for visible tiles
   - Reduces staging buffer writes and GPU uploads

3. **Batch similar entities**:
   - Group particles by texture/shader
   - Reduces batch count and state changes

4. **Monitor orphaning**:
   - Watch console for "Ring buffer wrapped" messages
   - If happening every frame, increase buffer size

## Comparison with Standard TileBatch

**Example: 1000 particles, all moving every frame**

### Standard TileBatch:
```
CPU: Generate 1000 tile vertices (20KB)
GPU: glBufferSubData uploads 20KB
Bandwidth: 20KB/frame @ 60fps = 1.2MB/s
```

### TileBatchStreaming:
```
CPU: Generate 1000 tile vertices (20KB), memcpy to mapped memory
GPU: Direct memory write (no API call overhead)
Bandwidth: Same 20KB/frame, but no driver overhead
Result: ~10-30% faster on many GPUs
```

## Migration Guide

To convert from TileBatch to TileBatchStreaming:

```haxe
// Before:
var batch = new TileBatch(programInfo, texture, 1000);

// After:
var batch = new TileBatchStreaming(programInfo, texture, 1000, 4);
//                                  Same API ──────────────────┘  │
//                                  Just add buffer size ─────────┘
```

All other code remains the same - it's a drop-in replacement!

## Summary

TileBatchStreaming implements the ring buffer streaming technique for maximum GPU upload performance. Use it when:
- Many tiles update frequently (>50% per frame)
- You need consistent frame times with heavy updates
- Memory isn't a constraint (4MB GPU memory is acceptable)

For static or sparsely-updated tilemaps, stick with standard TileBatch and per-tile uploads.
