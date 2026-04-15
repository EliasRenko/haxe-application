package;

import states.RunnerState;
import states.TestMixerState;
#if dll
import Editor;
#end

class Main {
    public static function main() {
        
        // Normal executable mode
        var app = new App();
        app.init();

        app.addState(new TestMixerState(app));
        app.run();
    }
}
