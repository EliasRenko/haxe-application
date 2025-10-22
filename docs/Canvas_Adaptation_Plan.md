# Canvas UI Adaptation Plan

## Overview
Adapt the `haxe-ui` Canvas UI system to work with `haxe-application`'s existing rendering architecture while preserving UI management capabilities.

---

## 1. Dependency Mapping

### Current haxe-ui Dependencies → haxe-application Equivalents

| haxe-ui Class | haxe-application Replacement | Notes |
|--------------|------------------------------|-------|
| `Tilemap` | `TileBatchFast` | Use for UI element rendering from texture atlas |
| `BitmapFont` | `Text` (display.Text.hx) | Already exists, uses mono shaders for 1bpp fonts |
| `View` | `Renderer` | Already integrated in App, use `app.renderer` |
| `State` | `State` | Already exists, Canvas extends Entity and lives in State |
| `Entity` | `Entity` | Canvas already extends Entity |
| `app.resources` | `Resources` | Already exists via `app.resources` |
| `app.input.mouse` | `Input.mouse` | Already exists via `app.input.mouse` |
| `app.input.keyboard` | `Input.keyboard` | Already exists via `app.input.keyboard` |

### New Classes to Port from haxe-ui

| Class | Purpose | Adaptation Required |
|-------|---------|---------------------|
| `Control` | Base UI element class | Remove haxe-ui EventDispacher, use simplified event system |
| `Container<T>` | Parent control for hierarchy | Adapt to use List or Array of Controls |
| `Canvas` | Main UI manager | Replace Tilemap with TileBatchFast, use Text instead of BitmapFont |

---

## 2. Architecture Analysis

### Canvas.hx Current Structure (haxe-ui)
```
Canvas extends Entity
├── Uses Tilemap for rendering UI elements
├── Uses BitmapFont for text rendering  
├── Manages Control hierarchy via RootContainer
├── Handles focus, marked controls, dialogs
├── Input handling from parent.app.input
├── Resources loaded via parentState.app.resources
└── Rendering via tilemap.render() and font.render()
```

### Canvas.hx Target Structure (haxe-application)
```
Canvas extends Entity
├── Uses TileBatchFast for UI element rendering
├── Uses Text (display.Text) for text rendering
├── Manages Control hierarchy via Container<Control>
├── Handles focus, marked controls, dialogs (preserved)
├── Input handling from app.input (Entity has state.app reference)
├── Resources via app.resources
└── Rendering via tileBatchFast.render() and textDisplay.render()
```

---

## 3. Key Differences & Required Changes

### 3.1 Rendering System

**haxe-ui approach:**
```haxe
// Tilemap with addTile/removeTile API
tilemap.addTile(tile);
tilemap.render(cameraMatrix);

// BitmapFont with render API
font.render(cameraMatrix);
```

**haxe-application approach:**
```haxe
// TileBatchFast with addTile/updateTile/removeTile API
var tileId = tileBatchFast.addTile(x, y, width, height, regionId);
tileBatchFast.updateTile(tileId, x, y, width, height, regionId);
tileBatchFast.removeTile(tileId);

// Entity/DisplayObject render via State
entity.render(renderer, viewProjectionMatrix);
// OR direct DisplayObject render:
tileBatchFast.render(cameraMatrix);

// Text rendering (already exists in display.Text.hx)
text.render(cameraMatrix);
```

### 3.2 Resource Loading

**haxe-ui:**
```haxe
var texture = parentState.app.resources.getImage('gui.png');
var sets = parentState.app.resources.getText('gui.json');
```

**haxe-application:**
```haxe
// Load texture data
var textureData = app.resources.getTexture('textures/gui.tga');
var texture = renderer.uploadTexture(textureData);

// Load JSON
var jsonText = app.resources.getText('text/gui.json');
var sets = haxe.Json.parse(jsonText);
```

### 3.3 Input System

**Both systems are compatible:**
```haxe
// Mouse position
var mouseX = app.input.mouse.x;
var mouseY = app.input.mouse.y;

// Mouse button state
var leftClick = app.input.mouse.released(1); // Button 1 = left mouse
```

**Note:** haxe-ui uses `leftClick` property, haxe-application uses `released(1)` method.

### 3.4 Component Hierarchy

**haxe-ui:**
```haxe
// Canvas manages RootContainer (private class)
private var __container:RootContainer;

// RootContainer wraps Container<Control>
class RootContainer extends Container<Control>
```

**haxe-application adaptation:**
```haxe
// Canvas can directly use Container<Control>
private var rootContainer:Container<Control>;

// Or use Array<Control> for simplicity
private var controls:Array<Control> = [];
```

---

## 4. Implementation Steps

### Phase 1: Core Infrastructure (Control & Container)

#### Step 1.1: Create `Control.hx` in haxe-application

**File:** `src/gui/Control.hx`

Key features to preserve:
- Position properties (`x`, `y`, `z`)
- Size properties (`width`, `height`)
- Visibility (`visible`, `active`)
- Hit testing (`hitTest()`)
- Event callbacks (`onMouseLeftClick`, `onMouseHover`, etc.)
- Parent/Canvas references

Changes from haxe-ui version:
- Remove `EventDispacher<Control>` base class (or simplify)
- Use `parent.app.input.mouse` instead of `canvas.mouseX/mouseY`
- Remove dependency on custom event system (or use simplified callbacks)

#### Step 1.2: Create `Container.hx` in haxe-application

**File:** `src/gui/Container.hx`

Key features:
- Generic `Container<T:Control>` for type-safe child management
- `addControl()` and `removeControl()` methods
- Hierarchical `update()` propagation
- Child initialization when Canvas is available

---

### Phase 2: Canvas Implementation

#### Step 2.1: Create Canvas.hx Structure

**File:** `src/gui/Canvas.hx`

```haxe
package gui;

import Entity;
import State;
import display.TileBatchFast;
import display.Text;
import Renderer;
import Input;

class Canvas extends Entity {
    // UI rendering
    private var tileBatchFast:TileBatchFast;
    private var textDisplay:Text;
    
    // UI management
    private var rootContainer:Container<Control>;
    private var focusedControl:Control = null;
    private var markedControl:Control = null;
    
    // Dialog system
    private var dialogs:Array<Dialog> = [];
    private var currentDialog:Dialog = null;
    
    // Input state
    public var mouseX(get, null):Float;
    public var mouseY(get, null):Float;
    public var leftClick(get, null):Bool;
    
    public function new(parentState:State) {
        super("canvas");
        // Initialize UI systems...
    }
}
```

#### Step 2.2: Texture Atlas Setup

**Similar to haxe-ui's `importSets()`:**

```haxe
public function loadUIAtlas(atlasTexturePath:String, metadataPath:String):Void {
    // Load atlas texture (gui.tga)
    var textureData = state.app.resources.getTexture(atlasTexturePath);
    var texture = state.app.renderer.uploadTexture(textureData);
    
    tileBatchFast.atlasTexture = texture;
    
    // Load atlas metadata (gui.json)
    var jsonText = state.app.resources.getText(metadataPath);
    var atlasData = haxe.Json.parse(jsonText);
    
    // Define regions in TileBatchFast
    for (region in (atlasData.regions:Array<Dynamic>)) {
        var regionId = tileBatchFast.defineRegion(
            region.x, region.y, 
            region.width, region.height
        );
        // Store mapping: region.name -> regionId
    }
}
```

#### Step 2.3: Control Management

```haxe
public function addControl(control:Control):Control {
    control.____canvas = this;
    control.____parent = null; // Top-level control
    rootContainer.addControl(control);
    return control;
}

public function removeControl(control:Control):Void {
    rootContainer.removeControl(control);
}
```

#### Step 2.4: Update Loop

```haxe
override public function update(deltaTime:Float):Void {
    super.update(deltaTime);
    
    // Update dialog if active, otherwise update root container
    if (currentDialog != null && currentDialog.visible) {
        currentDialog.update();
    } else {
        rootContainer.update();
    }
    
    // Handle focus changes
    if (markedControl != focusedControl) {
        if (focusedControl != null) {
            focusedControl.onFocusLost();
        }
        focusedControl = markedControl;
    }
    
    markedControl = null;
}
```

#### Step 2.5: Render Method

```haxe
override public function render(renderer:Renderer, viewProjectionMatrix:math.Matrix):Void {
    // Render UI elements via TileBatchFast
    if (tileBatchFast != null) {
        tileBatchFast.render(viewProjectionMatrix);
    }
    
    // Render text via Text display object
    if (textDisplay != null) {
        textDisplay.render(viewProjectionMatrix);
    }
}
```

---

### Phase 3: Control Subclasses

Port UI controls from haxe-ui to haxe-application:

| Control | File | Priority |
|---------|------|----------|
| `Button` | `src/gui/Button.hx` | High - Basic interaction |
| `Label` | `src/gui/Label.hx` | High - Text display |
| `Panel` | `src/gui/Panel.hx` | Medium - Container visual |
| `TextField` | `src/gui/TextField.hx` | Medium - Text input |
| `Checkbox` | `src/gui/Checkbox.hx` | Low - Advanced interaction |
| `List` | `src/gui/List.hx` | Low - Advanced control |

Each control will:
1. Extend `Control`
2. Use `TileBatchFast` tile IDs for graphics (store in `private var tileIds:Array<Int>`)
3. Use `Canvas.textDisplay` for rendering text
4. Implement `init()` to add tiles to batch
5. Implement `release()` to remove tiles from batch
6. Update tile positions in `__setGraphicX()` and `__setGraphicY()`

---

### Phase 4: Integration Example

#### Example: Button Control

```haxe
package gui;

class Button extends Control {
    private var bgTileId:Int = -1;
    private var labelText:String;
    
    public function new(text:String, x:Float, y:Float) {
        super(x, y);
        this.labelText = text;
        __type = 'button';
    }
    
    override function init():Void {
        super.init();
        
        // Add background tile to TileBatchFast
        var regionId = 1; // Assume region 1 is button background
        bgTileId = ____canvas.tileBatchFast.addTile(
            __x + ____offsetX, 
            __y + ____offsetY, 
            100, 32, // width, height
            regionId
        );
        
        __width = 100;
        __height = 32;
        
        // Add text rendering (to be implemented)
        // TODO: Canvas needs text rendering API
    }
    
    override function release():Void {
        // Remove tile from batch
        if (bgTileId != -1) {
            ____canvas.tileBatchFast.removeTile(bgTileId);
        }
        super.release();
    }
    
    override function __setGraphicX():Void {
        if (bgTileId != -1) {
            var tile = ____canvas.tileBatchFast.tiles.get(bgTileId);
            if (tile != null) {
                ____canvas.tileBatchFast.updateTile(
                    bgTileId, 
                    __x + ____offsetX, 
                    tile.y, 
                    tile.width, tile.height, 
                    tile.regionId
                );
            }
        }
    }
    
    override function __setGraphicY():Void {
        if (bgTileId != -1) {
            var tile = ____canvas.tileBatchFast.tiles.get(bgTileId);
            if (tile != null) {
                ____canvas.tileBatchFast.updateTile(
                    bgTileId, 
                    tile.x, 
                    __y + ____offsetY, 
                    tile.width, tile.height, 
                    tile.regionId
                );
            }
        }
    }
}
```

---

## 5. Text Rendering Strategy

### Challenge
haxe-ui uses `BitmapFont` with per-character rendering. haxe-application's `Text` class likely renders full strings.

### Solutions

#### Option A: Use Existing Text Class (Simplest)
```haxe
// Canvas creates multiple Text instances for UI elements
private var textDisplays:Array<Text> = [];

public function createTextLabel(text:String, x:Float, y:Float):Text {
    var textDisplay = new Text(programInfo, fontTexture);
    textDisplay.setText(text);
    textDisplay.x = x;
    textDisplay.y = y;
    textDisplays.push(textDisplay);
    return textDisplay;
}

// In render()
for (textDisplay in textDisplays) {
    textDisplay.render(viewProjectionMatrix);
}
```

#### Option B: Extend TileBatchFast for Characters (Advanced)
Use TileBatchFast to render individual character tiles from a font atlas. Each Control that needs text would add character tiles to the batch.

**Recommended:** Start with Option A for simplicity.

---

## 6. Testing Strategy

### Test State: `CanvasTestState.hx`

```haxe
package states;

import State;
import App;
import gui.Canvas;
import gui.Button;
import gui.Label;

class CanvasTestState extends State {
    private var canvas:Canvas;
    
    public function new(app:App) {
        super("CanvasTestState", app);
    }
    
    override public function init():Void {
        super.init();
        
        camera.ortho = true;
        
        // Create Canvas
        canvas = new Canvas(this);
        addEntity(canvas);
        
        // Load UI atlas
        canvas.loadUIAtlas("textures/gui.tga", "text/gui.json");
        
        // Create test button
        var button = new Button("Click Me", 100, 100);
        canvas.addControl(button);
        
        // Create test label
        var label = new Label("Hello UI!", 100, 150);
        canvas.addControl(label);
        
        trace("CanvasTestState: Created UI with " + 
              canvas.rootContainer.controls.length + " controls");
    }
}
```

---

## 7. Migration Checklist

### Phase 1: Infrastructure
- [ ] Create `src/gui/Control.hx`
- [ ] Create `src/gui/Container.hx`
- [ ] Test Control hierarchy and hit testing
- [ ] Test focus management

### Phase 2: Canvas Core
- [ ] Create `src/gui/Canvas.hx`
- [ ] Implement TileBatchFast integration
- [ ] Implement atlas loading (`loadUIAtlas()`)
- [ ] Implement `addControl()`/`removeControl()`
- [ ] Implement `update()` loop
- [ ] Implement `render()` method
- [ ] Test basic rendering

### Phase 3: Controls
- [ ] Port `Button.hx`
- [ ] Port `Label.hx`
- [ ] Test Button interaction
- [ ] Test Label rendering
- [ ] Port `Panel.hx` (optional)
- [ ] Port `TextField.hx` (optional)

### Phase 4: Testing
- [ ] Create `CanvasTestState.hx`
- [ ] Create test UI atlas (`gui.tga` + `gui.json`)
- [ ] Test mouse input and focus
- [ ] Test control hierarchy
- [ ] Test dialog system
- [ ] Performance testing

---

## 8. Potential Issues & Solutions

### Issue 1: Text Rendering Complexity
**Problem:** haxe-ui uses BitmapFont for per-character rendering, haxe-application uses Text for strings.

**Solution:** Use multiple Text instances per Canvas, or extend TileBatchFast to handle character tiles.

### Issue 2: Coordinate Systems
**Problem:** UI typically uses screen-space coordinates, but haxe-application uses world-space with camera matrix.

**Solution:** 
- Use orthographic camera with pixel-perfect mapping
- Canvas.hx already handles this via Entity's position and camera matrix
- Ensure camera is configured for 2D UI: `camera.ortho = true`

### Issue 3: Z-ordering for UI Layers
**Problem:** UI elements need consistent layering (buttons on top of panels, dialogs on top of everything).

**Solution:**
- Use `z` property in Control for depth sorting
- Render controls in z-order within Canvas.render()
- Dialog system already has separate rendering path

### Issue 4: Event System Differences
**Problem:** haxe-ui uses EventDispacher, haxe-application might use different pattern.

**Solution:**
- Simplify to direct method callbacks (`onMouseLeftClick()`, etc.)
- Remove EventDispacher dependency or create simplified version
- Use function properties for callbacks if needed

---

## 9. Asset Requirements

### GUI Texture Atlas (`gui.tga`)
Must contain sprites for:
- Button states (normal, hover, pressed)
- Panel borders and backgrounds
- Checkbox states
- Text field backgrounds
- Icons and decorations

### GUI Metadata (`gui.json`)
Example format:
```json
{
  "regions": [
    {"name": "button_normal", "x": 0, "y": 0, "width": 100, "height": 32},
    {"name": "button_hover", "x": 100, "y": 0, "width": 100, "height": 32},
    {"name": "panel_bg", "x": 0, "y": 32, "width": 200, "height": 150}
  ]
}
```

### Font Texture (`nokiafc22.tga` or similar)
- 1bpp font texture for mono shader
- Font metadata JSON with character metrics

---

## 10. Success Criteria

✅ Canvas extends Entity and integrates with State/App
✅ TileBatchFast renders UI elements from atlas
✅ Text class renders labels and button text
✅ Control hierarchy works (add/remove/update)
✅ Mouse input detected via app.input.mouse
✅ Focus management works (focused/marked controls)
✅ Hit testing correctly detects mouse over controls
✅ Dialog system functions (show/hide)
✅ Performance: UI updates don't cause stuttering
✅ Code is maintainable and follows haxe-application patterns

---

## Next Steps

1. **Review this plan** - Ensure approach aligns with project goals
2. **Create Phase 1** - Implement Control and Container classes
3. **Create Phase 2** - Implement Canvas core with TileBatchFast
4. **Test incrementally** - Create CanvasTestState early for rapid iteration
5. **Port controls** - Add Button, Label, and other controls as needed

---

*Document created: [Current Date]*
*Last updated: [Current Date]*
