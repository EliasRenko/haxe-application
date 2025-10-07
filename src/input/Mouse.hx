package input;

class Mouse {
    
    public var buttons:Array<ButtonState> = [];
    public var buttonMap:Map<Int, ButtonState> = new Map();

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
}

enum ButtonState {
    PRESSED;
    RELEASED;
}
