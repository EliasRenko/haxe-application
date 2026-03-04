package;

import states.RunnerState;

class Main {
    public static function main() {
        
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new RunnerState(app));
        app.run();
    }
}