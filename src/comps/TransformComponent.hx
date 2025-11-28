package comps;

import cog.IComponent;
import math.Transform;

/**
 * Component that holds transform data (position, rotation, scale)
 * Separated from rendering to allow entities with transforms but no rendering
 */
class TransformComponent implements IComponent {
	public var transform:Transform;

	public function new() {
		transform = new Transform();
	}
}
