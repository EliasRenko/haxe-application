package;

//import states.ImageTestState;
//import states.CollisionTest;
//import states.TextTestState;
import states.TileBatchFastTest;
//import states.AtlasState;
//import states.CanvasTestState;
import App;

class Main {
    public static function main() {
        
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new TileBatchFastTest(app));
        app.run();
    }
}
