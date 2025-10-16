package comps;

import Component;

/**
 * Rotates an entity continuously
 */
class RotationComp extends Component {
    public var rotationSpeed:Float = 0;
    
    public function new(speed:Float = 1.0) {
        super();
        this.rotationSpeed = speed;
    }
    
    override public function update(deltaTime:Float):Void {
        if (!enabled || entity == null) return;
        
        entity.rotationZ += rotationSpeed * deltaTime;
    }
}