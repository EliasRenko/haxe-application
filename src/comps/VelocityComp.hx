package comps;

import Component;

/**
 * Adds velocity-based movement to an entity
 * Works with TileComp
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
        
        // Update TileComp
        var tileComp = entity.getComponent(TileComp);
        if (tileComp != null) {
            var newX = tileComp.x + velocityX * deltaTime;
            var newY = tileComp.y + velocityY * deltaTime;
            tileComp.setPosition(newX, newY);
            return;
        }
    }
}