package;

import input.Keyboard;
import input.Mouse;

class Input {

    // Publics
    public var keyboard(get, null):Keyboard;
    public var mouse(get, null):Mouse;

    // Privates
    private var __keyboard:Keyboard;
    private var __mouse:Mouse;
    private var __parent:App;

    public function new(parent:App) {
        __parent = parent;

        __keyboard = new Keyboard();
        __mouse = new Mouse();
    }

    public function init():Void {
        
    }

    public function release():Void {
        
    }

    public function update():Void {
        __keyboard.update();
        __mouse.update();
    }

    public function postUpdate():Void {
        __keyboard.postUpdate();
        __mouse.postUpdate();
    }

    // Getters and setters
    private function get_keyboard():Keyboard {
        return __keyboard;
    }

    private function get_mouse():Mouse {
        return __mouse;
    }
}