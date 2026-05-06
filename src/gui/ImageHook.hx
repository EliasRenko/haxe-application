package gui;

import display.Image;

/**
 * ImageHook — a render-list marker that Canvas uses to interleave an
 * arbitrary Image draw call within the UIBatch tile stream.
 *
 * Owned by ImageView; registered with Canvas via registerImageHook().
 * Canvas reads `displayImage` and `visible` each frame during render.
 */
class ImageHook {
    /** The Image DisplayObject to draw at this position in the render list. */
    public var displayImage:Image = null;

    /** When false, Canvas skips this hook entirely (same as control.visible). */
    public var visible:Bool = true;

    public function new() {}
}
