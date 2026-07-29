package;

import states.GUITestState;
import states.MenuState;
import states.RunnerState;
#if dll
import Editor;
#end

class Main {
    public static function main() {
        var app = new App();
        app.init();

        app.addState(new MenuState(app));
        app.addState(new GUITestState(app));
        #if cpp
        app.addState(new states.FontBakerState(app));
        app.addState(new states.PackerState(app));
        #end
        app.run();
    }

    // public static function main() {
    //     var app = new App();
    //     app.init();

    //     app.addState(new states.FontBakerState(app));
    //     app.addState(new states.PackerState(app));

    //     app.run();
    // }
}
