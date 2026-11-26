haxe-application
===
Rendering object based application with SDL3 backend.

## Camera

The default orthographic camera uses the drawable window size. A virtual size
is optional and follows window or viewport resizing:

```haxe
import Camera.SizeMode;
import math.Vec2;

camera.ortho = true;
camera.size = new Vec2(320, 180);
camera.sizeMode = SizeMode.fit;
camera.zoom = 1;
```

`fit` shows the entire virtual area, including additional world area if the
aspect ratios differ. `cover` fills the viewport and may crop; `contain`
stretches independently on each axis. Set `size` to `null` to return to the
viewport-sized default. The `size` getter returns a copy.

An optional `camera.viewport = {x: 0, y: 0, width: 640, height: 360}` selects
a drawable rectangle in window pixels; `null` restores the full window.
Screen conversion helpers accept full-window screen dimensions, so logical
input coordinates can differ from drawable pixels.

`minimumZoom` limits zoom (zero disables the minimum). Optional world `bounds`
keep the visible area inside the rectangle, or center it when the view is
larger. `focus(x, y)` centers the view immediately, subject to bounds.
Bounds, focus, and the 2D conversion helpers require an unrotated orthographic
camera. `shake(amount, duration)` adds a temporary decaying render offset
without changing the camera position. States advance it automatically; when
using a camera independently, call `camera.update(deltaTime)` in seconds.
