# GUI System Review

## Overview

The `gui/` package contains 19 files implementing a tile-based retained-mode UI framework. Controls are rendered via a `ManagedTileBatch` (tiles) and `BitmapFont` (text), rooted in a `Canvas` which owns a hidden `RootContainer`. The hierarchy is:

```
Canvas
  └─ RootContainer (Container)
       └─ Control (base)
            ├─ Container<T>
            │    ├─ Panel          (NineSlice background)
            │    ├─ Strip          (ThreeSlice bar)
            │    │    └─ Toolstrip (auto-layout strip)
            │    ├─ List<T>        (vertical list)
            │    │    └─ ListItem  (row wrapper)
            │    ├─ Window         (Strip + Panel composite)
            │    │    └─ Dialog
            │    └─ Toolstripmenu  (menu bar)
            ├─ Button              (ThreeSlice + text)
            ├─ Label               (BitmapFont text)
            ├─ Checkbox            (toggle tile)
            ├─ Stamp               (single icon tile)
            └─ TextField           (ThreeSlice + text input)
```

Supporting abstracts: `NineSlice`, `ThreeSlice`  
Event enum: `ControlEventType`

---

## Bugs & Issues

### Critical

**1. Control.update() — `onMouseEnter` / `onMouseLeave` logic is inverted**

In `Control.update()`:
```haxe
if (__hover) {
    onMouseHover();
}
else {
    onMouseEnter(); // called every frame when mouse is OUTSIDE the control
}
```
`onMouseEnter()` sets `__hover = true` and marks the control — this is called continuously when the mouse is NOT hovering. The intended logic should guard `onMouseEnter` to only fire on the first frame the mouse enters, and `onMouseLeave` should fire on the first frame it exits. Fix: track previous hover state and compare.

**2. TextField is non-functional**

- `onFocusGain`, `onFocusLost`, `__onkeyInputEvent`, and `__onTextInputEvent` all have their bodies fully commented out.
- `update()` calls `____canvas.onTextInput(this)` — `Canvas` has no such method.
- `init()` calls `____canvas.tilemap.addTile(tile)` — the API is `addTileInstance`.
- `__initGraphics()` sets `__threeSlice.get(0).id = ...` but `Tile` uses `.regionId`, not `.id`.

**3. `Canvas.onTextInput` does not exist**

`TextField.update()` calls `____canvas.onTextInput(this)` unconditionally while focused. This method is missing from `Canvas`. A keyboard input integration path needs to be established.

**4. `Toolstrip` ignores the `width` constructor parameter**

```haxe
public function new(width:Float, x:Float, y:Float) {
    super(640, x, y); // width is silently discarded
}
```
Should be `super(width, x, y)`.

**5. `List.removeControl` measures the wrong height**

```haxe
height -= control.height; // 'control' is the inner item, not the ListItem wrapper
```
Should subtract `listItem.height` to keep the total height accurate.

**6. `Window.__onCloseClickEvent` toggles instead of closing**

```haxe
visible = visible ? false : true;
```
A close button should unconditionally hide the window and dispatch a `REMOVED`-style event, not toggle visibility. This also prevents listeners from knowing the window was closed.

**7. `active(get, null)` declares no setter but `set_active` is defined**

The property is declared `public var active(get, null)` — the `null` accessor suppresses the setter in the property definition, but `set_active(value:Bool)` is written below it. The property should be `(get, set)` or the setter should be removed.

---

### Design / Architecture Issues

**8. No keyboard navigation**

`ON_TAB_INDEX_CHANGE` is defined in `ControlEventType` but `Control` has no `tabIndex` field and no tab-cycling logic in `Canvas`.

**9. No right-click support**

`RIGHT_CLICK` is in `ControlEventType` and `Canvas.leftClick` exists, but there is no `rightClick` getter or dispatch path.

**10. No z-order management**

`Control.z` exists but `Container.update()` does not sort by z before hit-testing, and the tilemap z is managed independently. Controls added later always occlude earlier ones regardless of z value.

**11. `ToolstripPanel` has no "click outside to dismiss" behaviour**

The dropdown panel shows on focus gain but nothing closes it when focus moves elsewhere. `onFocusLost` hides it, but `Canvas.focusedControl` is only changed when a new control calls `onFocusGain` — clicking on empty space does nothing.

**12. No scrollable container**

`List` grows downward indefinitely. There is no clipping or scrollbar. With many items the list overflows the canvas.

**13. Window is not draggable**

`ON_DRAG` events are defined but never dispatched. The `Window` title strip has no drag-to-move logic.

**14. Dialog has no modal behaviour**

`Dialog` extends `Window` with only a type change. It does not block input to controls beneath it, does not darken the background, and has no OK/Cancel pattern.

**15. Hardcoded texture key strings**

Every component uses string literals like `'panel_1'`, `'checkbox_0'`, `'strip_2'` to look up region IDs. Typos are silently `null` at runtime. A typed constant or enum would catch errors at compile time.

**16. `____canvas` naming (4 underscores)**

The field is accessed with `@:privateAccess` hacks across the codebase. Using 4 underscores is unconventional and the `@:privateAccess` pattern suggests the architecture would benefit from a cleaner injection mechanism (e.g. passing canvas through `init(canvas)` rather than injecting after construction).

**17. `Canvas.width/height` unused for bounds clipping**

Controls can be positioned and rendered outside the canvas rectangle with no clipping.

---

## Missing Components

The following controls are commonly needed and absent from the current system:

| Component | Notes |
|---|---|
| **Slider / ScrollBar** | Texture keys `slider_0/1/2` are already referenced in `TextField`. The component is simply not implemented. |
| **ProgressBar** | Horizontal/vertical fill indicator. |
| **RadioButton / RadioGroup** | Mutually exclusive toggle; needs group coordination. |
| **ComboBox / DropDown** | Text field + button that reveals a `List`. Can be built from existing parts. |
| **TabBar / TabPanel** | Strip of tab buttons that swap a content panel. |
| **NumberInput / Spinner** | `TextField` with up/down buttons and numeric validation. |
| **Separator** | Thin visual divider for use inside panels and menus. |
| **Tooltip** | Floating label that follows the cursor on hover delay. |
| **ContextMenu** | Right-click popup `List`. Needs right-click input path (issue #9). |
| **TreeView** | Hierarchical foldable list. `ON_FOLD_CLICK` is already in `ControlEventType`. |
| **ScrollableContainer** | Panel with a clipped viewport and a `ScrollBar`. |
| **Splitter** | Draggable divider between two resizable panels. |

---

## Proposed Improvements

### 1. Fix the hover state machine in `Control`

Replace the current update logic with an explicit enter/leave state transition:

```haxe
// In Control
private var __wasHover:Bool = false;

override function update():Void {
    var isHit = hitTest();
    if (isHit && !__wasHover) onMouseEnter();
    else if (!isHit && __wasHover) onMouseLeave();
    if (isHit) onMouseHover();
    __wasHover = isHit;
    // ... click handling
}
```

This removes the dependency on `Canvas.markedControl` for leave events and decouples hover state management from the canvas.

### 2. Introduce a typed skin / theme constant class

Replace string keys with a typed class:

```haxe
class UISkin {
    public static inline var PANEL_TL   = "panel_1";
    public static inline var PANEL_T    = "panel_2";
    // ...
    public static inline var BUTTON_L   = "button_0";
    // ...
}
```

Or better, use an `enum abstract` so mismatches are caught at compile time.

### 3. Add layout containers

Add `HBox` and `VBox` containers that automatically position their children:

- `HBox` — arranges children left to right with configurable spacing and padding.
- `VBox` — arranges children top to bottom (replaces the manual y-accumulation in `List` and `Toolstrip`).
- Optionally `GridLayout` for fixed column/row grids.

`Toolstrip` can be refactored to extend `HBox` rather than reimplementing layout itself.

### 4. Add `ScrollableContainer`

A container that:
- Clips rendering to its bounds (via scissor rect in the renderer if supported, or by culling tiles outside the rect).
- Contains a vertical `ScrollBar` child.
- Offsets child controls by a scroll offset rather than their absolute positions.

### 5. Keyboard input integration

- Add `tabIndex:Int` to `Control`.
- Add a `Canvas.onKeyDown(key)` and `Canvas.onTextInput(char)` method that the parent state calls each frame.
- `Canvas` routes text input to `focusedControl` directly.
- Tab cycling: `Canvas` tracks a sorted list of focusable controls and shifts focus on Tab.

### 6. Make Window draggable

In `WindowStrip.update()`, detect a mouse-down on the strip area and accumulate mouse delta to `Window.x / Window.y`. Uses the existing `ON_DRAG` event path.

### 7. Add modal Dialog support

`Dialog` should:
- Render a semi-transparent `DarkOverlay` behind itself (the class already exists in `display/`).
- Block all canvas input to controls beneath it by short-circuiting `Container.update()`.
- Expose `confirm` and `cancel` callbacks / events.

### 8. Add `ContextMenu`

- `Canvas` gains a `rightClick` getter mirroring `leftClick`.
- A `ContextMenu` control is a floating `Panel` containing a `List` of `Label` items.
- It is shown at `(mouseX, mouseY)` and dismissed on any click outside.

### 9. Implement `Slider`

Use the existing `slider_0/1/2` texture keys. A `Slider` is a `ThreeSlice` background with a `Stamp` handle that can be dragged along its length. Exposes `value:Float` (0..1) and dispatches `ON_DRAG`.

### 10. Improve `ToolstripPanel` dismissal

`Canvas` should detect a click outside any focused drop-down and call `focusedControl.onFocusLost()`. This can be done in the root container's update pass when no child reports a hit.

---

## Prioritised Roadmap

### Phase 1 — Bug fixes (no new features)
1. Fix `Control.update()` hover logic
2. Fix `TextField` API calls (`addTileInstance`, `.regionId`, remove invalid `onTextInput` call)
3. Fix `Toolstrip` width parameter
4. Fix `List.removeControl` height calculation
5. Fix `Window` close event
6. Fix `active` property declaration

### Phase 2 — Core missing functionality
7. Keyboard input path in `Canvas` + `TextField` wiring
8. `Slider` control (textures already defined)
9. Right-click path + `ContextMenu`
10. `ScrollableContainer` + `ScrollBar`
11. Draggable `Window`

### Phase 3 — New components
12. `Separator`
13. `ProgressBar`
14. `RadioButton` / `RadioGroup`
15. `NumberInput` / `Spinner`
16. `Tooltip`
17. `ComboBox` / `DropDown`
18. `TabBar` / `TabPanel`
19. `TreeView`
20. `Splitter`

### Phase 4 — Architecture
21. Typed skin constants
22. Layout containers (`HBox`, `VBox`)
23. z-order sorting in `Container`
24. Modal `Dialog` with `DarkOverlay`
25. Tab/focus navigation
