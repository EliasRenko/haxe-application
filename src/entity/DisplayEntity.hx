package entity;

import Entity;
import DisplayObject;

/**
 * Entity subclass that always has a DisplayObject for rendering.
 */
class DisplayEntity extends Entity {
    /**
     * The DisplayObject to render for this entity.
     */
    public var displayObject:DisplayObject;

    /**
     * Create a new DisplayEntity with a DisplayObject.
     * @param displayObject The DisplayObject to attach and render.
     * @param id Optional entity id.
     */
    public function new(displayObject:DisplayObject, ?id:String) {
        super(id);
        this.displayObject = displayObject;
    }

    /**
     * Render this entity's DisplayObject if active and visible.
     */
    override public function render(renderer:Dynamic, viewProjectionMatrix:math.Matrix):Void {
        if (!active || !visible || displayObject == null || !displayObject.visible) {
            return;
        }
        renderer.renderDisplayObject(displayObject, viewProjectionMatrix);
    }

    /**
     * Clean up the DisplayObject and other resources.
     */
    override public function cleanup(renderer:Renderer):Void {
        if (displayObject != null) {
            displayObject.release(renderer);
        }
        super.cleanup(renderer);
    }
}
