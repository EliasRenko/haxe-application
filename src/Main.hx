package;

//import states.ImageTestState;
import states.CollisionTest;
import App;

class Main {
    public static function main() {
        
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new CollisionTest(app));
        app.run();
    }
}
