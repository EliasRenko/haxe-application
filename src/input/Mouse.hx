package input;

class Mouse {
    
    public var buttons:Array<ButtonState> = [];
    public var buttonMap:Map<Int, ButtonState> = new Map();
    public var x(get, null):Float = 0;
    public var y(get, null):Float = 0;

    // Privates
    private var __x:Float = 0;
    private var __y:Float = 0;

    public function new() {
        for (i in 0...8) {
            buttons[i] = ButtonState.RELEASED;
            buttonMap.set(i, buttons[i]);
        }
    }

    public function init():Void {
        for (i in 0...8) {
            buttons[i] = ButtonState.RELEASED;
            buttonMap.set(i, buttons[i]);
        }
    }

    public function updateButton(buttonCode:Int, state:ButtonState):Void {
        buttons[buttonCode] = state;
        buttonMap.set(buttonCode, state);
    }

    public function isButtonPressed(buttonCode:Int):Bool {
        return buttonMap.exists(buttonCode) && buttonMap.get(buttonCode) == ButtonState.PRESSED;
    }

    public function isButtonReleased(buttonCode:Int):Bool {
        return buttonMap.exists(buttonCode) && buttonMap.get(buttonCode) == ButtonState.RELEASED;
    }

    public function update():Void {
        
    }

    public function postUpdate():Void {
        //__pressCount = 0;
        //__releaseCount = 0;
    }

    private function onButtonPressed(x:Float, y:Float, button:Int):Void {
        updateButton(button, ButtonState.PRESSED);
        trace("Mouse button pressed: " + button);
    }

    private function onButtonReleased(x:Float, y:Float, button:Int):Void {
        updateButton(button, ButtonState.RELEASED);
        trace("Mouse button released: " + button);
    }

    private function onMouseMotion(x:Float, y:Float, xrel:Float, yrel:Float):Void {
        __x = x;
        __y = y;
    }

    // Getters and setters
    private function get_x():Float {
        return __x;
    }

    private function get_y():Float {
        return __y;
    }
}

enum ButtonState {
    PRESSED;
    RELEASED;
}
