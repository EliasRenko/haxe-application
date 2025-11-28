package comps;

import cog.IComponent;
import DisplayObject;

/**
 * Component that holds a DisplayObject for rendering
 * Separated from transform to allow entities with rendering but no spatial position
 */
class RenderComponent implements IComponent {
	public var displayObject:DisplayObject;

	public function new(displayObject:DisplayObject) {
		this.displayObject = displayObject;
	}
}
