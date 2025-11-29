package;

//import states.AtlasState;
import App;
//import states.CollisionTestState;
//import states.UITestState;
import states.TileBatchPerformanceTest;

class Main {
    public static function main() {
        
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new TileBatchPerformanceTest(app));
        //app.addState(new UITestState(app));
        app.run();
    }
}
