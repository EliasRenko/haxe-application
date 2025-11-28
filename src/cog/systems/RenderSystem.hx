package cog.systems;

import cog.System;
import cog.Node;
import comps.TransformComponent;
import comps.RenderComponent;
import Renderer;
import Camera;
import math.Matrix;

/**
 * RenderSystem processes all entities with TransformComponent + RenderComponent
 * Combines transform matrices with camera and renders to screen
 */
class RenderSystem extends System {
	public var renderer:Renderer;
	public var camera:Camera;

	// Cog @:nodes macro automatically queries entities with both components
	@:nodes var renderables:Node<TransformComponent, RenderComponent>;

	public function new(renderer:Renderer, camera:Camera) {
		super();
		this.renderer = renderer;
		this.camera = camera;
	}

	override public function step(dt:Float):Void {
		// Update camera projection matrix
		camera.renderMatrix(renderer.windowWidth, renderer.windowHeight);
		var viewProjectionMatrix = camera.getMatrix();

		// Iterate all entities with both TransformComponent and RenderComponent
		for (node in renderables) {
			var displayObject = node.render_component.displayObject;
			
			// Skip invisible objects
			if (!displayObject.visible) continue;

			// Update transform matrix if dirty
			node.transform_component.transform.update();

			// Set uniforms - GPU multiply approach (uModel * uView in shader)
			// This avoids allocating a final matrix per object
			//displayObject.uniforms.set("uModel", node.transform_component.transform.matrix.data);
			//displayObject.uniforms.set("uView", viewProjectionMatrix.data);

            var finalMatrix = Matrix.copy(node.transform_component.transform.matrix);
            finalMatrix.append(viewProjectionMatrix);
            
            // Set the transform matrix in uniforms map
            displayObject.uniforms.set("uMatrix", finalMatrix.data);

			// Render the display object
			renderer.renderDisplayObject(displayObject, viewProjectionMatrix);
		}
	}
}
