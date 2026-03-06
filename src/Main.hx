package;

#if dll
import Editor;
#end

class Main {
    public static function main() {
        
        // Normal executable mode
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new states.ParticleState(app));
        app.run();
    }
}
