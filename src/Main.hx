package;

import states.RunnerState;
#if dll
import Editor;
#end

class Main {
    public static function main() {
        
        // Normal executable mode
        var app = new App();
        app.init();

        app.addState(new RunnerState(app));
        app.run();
    }
}
