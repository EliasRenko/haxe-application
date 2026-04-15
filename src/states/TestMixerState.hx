package states;

import Log.LogCategory;
import SDLMixer.MIX;
import SDLMixer.MixerPtr;
import SDLMixer.MixAudioPtr;
import SDLMixer.TrackPtr;

/**
 * TestMixerState — a minimal walkthrough of SDL_mixer 3 (via the MIX externs).
 *
 * SDL_mixer 3 lifecycle (do these in order every time):
 *
 *   1.  MIX.init()                       — load SDL_mixer dynamic library
 *   2.  MIX.createMixerDevice(...)       — open the audio device & create a mixer
 *   3.  MIX.loadAudio(mixer, path, ...)  — decode / reference audio data from disk
 *   4.  MIX.createTrack(mixer)           — create an independent playback channel
 *   5.  MIX.setTrackAudio(track, audio)  — wire the audio data to the track
 *   6.  MIX.playTrack(track, 0)          — start playing
 *   ... (update loop) ...
 *   7.  MIX.stopTrack(track, 0)          — stop immediately (or with fade frames)
 *   8.  MIX.destroyTrack(track)          — free the track
 *   9.  MIX.destroyAudio(audio)          — free the audio data
 *   10. MIX.destroyMixer(mixer)          — close the audio device
 *   11. MIX.quit()                       — unload the library
 *
 * Controls in this test:
 *   SPACE       — toggle play / pause
 *   S           — stop and rewind
 *   + / =       — volume up   (master gain)
 *   -           — volume down (master gain)
 *   L           — toggle infinite looping
 */
class TestMixerState extends State {

    // -------------------------------------------------------------------------
    //  Constants
    // -------------------------------------------------------------------------

    // Path relative to the working directory (res/ is the resource root)
    private static inline var MUSIC_PATH:String = "res/music/Balatro.ogg";

    // How much to change the master gain per key press
    private static inline var GAIN_STEP:Float = 0.1;

    // Clamp the gain so we never accidentally blow the speakers
    private static inline var GAIN_MAX:Float  = 2.0;
    private static inline var GAIN_MIN:Float  = 0.0;

    // -------------------------------------------------------------------------
    //  SDL_mixer handles
    // -------------------------------------------------------------------------

    // The mixer owns one audio device; all tracks are mixed into it.
    private var _mixer:MixerPtr = null;

    // Audio holds the decoded (or reference to compressed) file data.
    private var _audio:MixAudioPtr = null;

    // A track is a single playing "voice" — we only need one here.
    private var _track:TrackPtr = null;

    // -------------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------------

    private var _gain:Float   = 1.0;   // current master gain (1.0 = 100 %)
    private var _looping:Bool = true;  // true while infinite looping is active
    private var _ready:Bool   = false; // set to true once init succeeds

    // -------------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------------

    public function new(app:App) {
        super("TestMixer", app);
    }

    // -------------------------------------------------------------------------
    //  Lifecycle
    // -------------------------------------------------------------------------

    override public function init():Void {
        super.init();

        var log = app.log;

        // ------------------------------------------------------------------
        // Step 1 — initialise the SDL_mixer library itself.
        // This must be called once before any other MIX function.
        // ------------------------------------------------------------------
        if (!MIX.init()) {
            log.error(LogCategory.SYSTEM, "MIX.init() failed");
            return;
        }
        log.debug(LogCategory.SYSTEM, "SDL_mixer version: " + MIX.version());

        // ------------------------------------------------------------------
        // Step 2 — open the default audio output device.
        // Passing MIX.defaultPlaybackDevice() lets SDL pick the OS default.
        // Passing null for the spec lets SDL_mixer choose the best format.
        // ------------------------------------------------------------------
        _mixer = MIX.createMixerDevice(MIX.defaultPlaybackDevice(), null);
        if (_mixer == null) {
            log.error(LogCategory.SYSTEM, "MIX.createMixerDevice() failed");
            MIX.quit();
            return;
        }

        // ------------------------------------------------------------------
        // Step 3 — load the audio file from disk.
        // predecode = false  → stream from compressed data (lower RAM, tiny CPU cost)
        // predecode = true   → fully decode up front (higher RAM, zero decode CPU)
        // For a long music track, streaming is usually the right choice.
        // ------------------------------------------------------------------
        _audio = MIX.loadAudio(_mixer, MUSIC_PATH, false);
        if (_audio == null) {
            log.error(LogCategory.SYSTEM, "MIX.loadAudio() failed for: " + MUSIC_PATH);
            MIX.destroyMixer(_mixer);
            MIX.quit();
            return;
        }

        // ------------------------------------------------------------------
        // Step 4 — create a track (playback channel) on our mixer.
        // ------------------------------------------------------------------
        _track = MIX.createTrack(_mixer);
        if (_track == null) {
            log.error(LogCategory.SYSTEM, "MIX.createTrack() failed");
            MIX.destroyAudio(_audio);
            MIX.destroyMixer(_mixer);
            MIX.quit();
            return;
        }

        // ------------------------------------------------------------------
        // Step 5 — wire the audio data to the track.
        // ------------------------------------------------------------------
        if (!MIX.setTrackAudio(_track, _audio)) {
            log.error(LogCategory.SYSTEM, "MIX.setTrackAudio() failed");
        }

        // Set gain and initial loop mode before we start playing
        MIX.setMixerGain(_mixer, _gain);
        MIX.setTrackLoops(_track, _looping ? -1 : 0); // -1 = infinite

        // ------------------------------------------------------------------
        // Step 6 — start playback.
        // The second argument is an SDL_PropertiesID (0 = default options).
        // ------------------------------------------------------------------
        if (!MIX.playTrack(_track, 0)) {
            log.error(LogCategory.SYSTEM, "MIX.playTrack() failed");
        } else {
            log.debug(LogCategory.SYSTEM, "Playing: " + MUSIC_PATH);
        }

        _ready = true;
        log.debug(LogCategory.SYSTEM,
            "TestMixerState ready — SPACE=play/pause  S=stop  +/-=volume  L=loop");
    }

    // -------------------------------------------------------------------------
    //  Update
    // -------------------------------------------------------------------------

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime); // handles camera debug keys

        if (!_ready) return;

        var kb  = app.input.keyboard;
        var log = app.log;

        // SPACE — toggle play / pause
        if (kb.released(Keycode.SPACE)) {
            if (MIX.trackPaused(_track)) {
                MIX.resumeTrack(_track);
                log.debug(LogCategory.SYSTEM, "Resumed");
            } else if (MIX.trackPlaying(_track)) {
                MIX.pauseTrack(_track);
                log.debug(LogCategory.SYSTEM, "Paused");
            } else {
                // Track stopped (exhausted) — restart from the beginning
                MIX.playTrack(_track, 0);
                log.debug(LogCategory.SYSTEM, "Restarted");
            }
        }

        // S — stop immediately and rewind to position 0
        if (kb.released(Keycode.S)) {
            MIX.stopTrack(_track, 0); // 0 fade frames = immediate stop
            MIX.setTrackPlaybackPosition(_track, 0);
            log.debug(LogCategory.SYSTEM, "Stopped & rewound");
        }

        // + / = — volume up
        if (kb.released(Keycode.EQUALS)) {
            _gain = Math.min(_gain + GAIN_STEP, GAIN_MAX);
            MIX.setMixerGain(_mixer, _gain);
            log.debug(LogCategory.SYSTEM, "Gain: " + _gain);
        }

        // - — volume down
        if (kb.released(Keycode.MINUS)) {
            _gain = Math.max(_gain - GAIN_STEP, GAIN_MIN);
            MIX.setMixerGain(_mixer, _gain);
            log.debug(LogCategory.SYSTEM, "Gain: " + _gain);
        }

        // L — toggle looping on the track
        if (kb.released(Keycode.L)) {
            _looping = !_looping;
            MIX.setTrackLoops(_track, _looping ? -1 : 0);
            log.debug(LogCategory.SYSTEM, "Looping: " + (_looping ? "ON" : "OFF"));
        }
    }

    // -------------------------------------------------------------------------
    //  Release — always mirror init() in reverse order
    // -------------------------------------------------------------------------

    override public function release():Void {
        super.release();

        if (!_ready) return;

        // Step 7 — stop the track (0 = immediate, no fade-out)
        MIX.stopTrack(_track, 0);

        // Step 8 — free the track handle
        MIX.destroyTrack(_track);
        _track = null;

        // Step 9 — free the audio data
        MIX.destroyAudio(_audio);
        _audio = null;

        // Step 10 — close the audio device
        MIX.destroyMixer(_mixer);
        _mixer = null;

        // Step 11 — unload the SDL_mixer shared library
        MIX.quit();

        _ready = false;
        app.log.debug(LogCategory.SYSTEM, "TestMixerState released");
    }
}
