class AppAudioSmoke {
    static function check(ok:Bool, message:String):Void {
        if (!ok) throw message;
    }

    static function main():Void {
        var app = new App();
        var rejected = false;
        try {
            var unused = app.audio;
        } catch (_:Dynamic) {
            rejected = true;
        }
        check(rejected, "Audio must not open before mixer initialization");

        check(SDLMixer.init(), "SDL_mixer initialization failed");
        @:privateAccess app.__audioEnabled = true;
        var audio = app.audio;
        check(app.audio == audio, "App must reuse its mixer");
        audio.release();
        var replacement = app.audio;
        check(replacement != audio, "App must replace a released mixer");
        replacement.release();
        SDLMixer.quit();
        @:privateAccess app.__audioEnabled = false;
        trace("App audio smoke test passed");
    }
}
