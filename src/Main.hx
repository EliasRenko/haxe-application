package;

import states.GUITestState;
import states.MenuState;
import states.RunnerState;
import states.TestMixerState;
import states.TestOpenALState;
#if dll
import Editor;
#end

class Main {
    public static function main() {
        
        // Normal executable mode
        var app = new App();
        app.init();

        //app.addState(new MenuState(app));
        app.addState(new GUITestState(app));
        app.run();
    }
}
