package;

//import states.ImageTestState;
//import states.CollisionTest;
//import states.TextTestState;
import states.TileBatchFastTest;
import states.AtlasState;
import App;
import states.CollisionTestState;
import states.UITestState;

class Main {
    public static function main() {
        
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new UITestState(app));
        app.run();
    }
}
