package comps;

import Component;

/**
 * Adds velocity-based movement to an entity
 * Works with both DisplayObjectComp and TileComp
 */
class VelocityComp extends Component {
    public var velocityX:Float = 0;
    public var velocityY:Float = 0;
    
    public function new(vx:Float = 0, vy:Float = 0) {
        super();
        this.velocityX = vx;
        this.velocityY = vy;
    }
    
    override public function update(deltaTime:Float):Void {
        if (!enabled || entity == null) return;
        
        // Try to update DisplayObjectComp first
        var displayComp = entity.getComponent(DisplayObjectComp);
        if (displayComp != null) {
            displayComp.x += velocityX * deltaTime;
            displayComp.y += velocityY * deltaTime;
            return;
        }
        
        // Otherwise try to update TileComp
        var tileComp = entity.getComponent(TileComp);
        if (tileComp != null) {
            var newX = tileComp.x + velocityX * deltaTime;
            var newY = tileComp.y + velocityY * deltaTime;
            tileComp.setPosition(newX, newY);
            return;
        }
    }
}