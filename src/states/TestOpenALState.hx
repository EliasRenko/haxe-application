package states;

import Log.LogCategory;
import cpp.RawPointer;
import cpp.Int16;
import OAL;
import OAL.ALCDevicePtr;
import OAL.ALCContextPtr;

/**
 * TestOpenALState — minimal walkthrough of OpenAL via the OAL externs.
 *
 * OpenAL lifecycle (do these in order every time):
 *
 *   1.  OAL.openDevice(null)           — open the default OS audio device
 *   2.  OAL.createContext(device, null) — create a context on that device
 *   3.  OAL.makeContextCurrent(ctx)    — make the context active
 *   4.  OAL.loadOgg(path, ...)         — decode OGG → 16-bit PCM (stb_vorbis)
 *   5.  OAL.genBuffer()                — allocate an AL buffer ID
 *   6.  OAL.bufferData(...)            — upload PCM into the buffer
 *   7.  OAL.freeOggPcm(pcm)            — free the decoder's heap allocation
 *   8.  OAL.genSource()                — allocate an AL source ID
 *   9.  OAL.sourcei(src, AL_BUFFER, buf) — attach the buffer to the source
 *   10. OAL.sourcei(src, AL_LOOPING, 1) — configure loop mode
 *   11. OAL.sourcePlay(src)            — start playback
 *   ... (update loop) ...
 *   12. OAL.sourceStop(src)            — stop
 *   13. OAL.deleteSource(src)          — free source
 *   14. OAL.deleteBuffer(buf)          — free buffer
 *   15. OAL.makeContextCurrent(null)   — detach context
 *   16. OAL.destroyContext(ctx)        — destroy context
 *   17. OAL.closeDevice(device)        — close device
 *
 * Controls:
 *   SPACE       — toggle play / pause
 *   S           — stop and rewind
 *   + / =       — volume up   (source gain)
 *   -           — volume down (source gain)
 *   L           — toggle infinite looping
 *   1           — toggle Reverb (Room)
 *   2           — toggle Reverb (Cathedral)
 *   3           — toggle Echo
 *   4           — toggle Chorus
 *   5           — toggle Flanger
 *   6           — toggle Distortion
 *   7           — toggle Ring Modulator (440 Hz)
 *   8           — toggle Pitch Shifter (+1 octave)
 *   9           — toggle Autowah
 *   (pressing the same key again turns the effect off)
 */
class TestOpenALState extends State {

    // -------------------------------------------------------------------------
    //  Constants
    // -------------------------------------------------------------------------

    private static inline var MUSIC_PATH:String = "res/music/Balatro.ogg";

    private static inline var GAIN_STEP:Float = 0.1;
    private static inline var GAIN_MAX:Float  = 2.0;
    private static inline var GAIN_MIN:Float  = 0.0;

    private static inline var NUM_EFFECTS:Int = 9;

    private static var EFFECT_NAMES:Array<String> = [
        "Reverb (Room)",           // key 1
        "Reverb (Cathedral)",      // key 2
        "Echo",                    // key 3
        "Chorus",                  // key 4
        "Flanger",                 // key 5
        "Distortion",              // key 6
        "Ring Modulator (440 Hz)", // key 7
        "Pitch Shifter (+1 oct)",  // key 8
        "Autowah"                  // key 9
    ];

    // -------------------------------------------------------------------------
    //  OpenAL handles
    // -------------------------------------------------------------------------

    private var _device  :ALCDevicePtr  = null;
    private var _context :ALCContextPtr = null;

    private var _buffer:cpp.UInt32 = 0;
    private var _source:cpp.UInt32 = 0;

    // -------------------------------------------------------------------------
    //  EFX handles  (valid only when _efxReady == true)
    // -------------------------------------------------------------------------

    private var _efxReady    :Bool          = false;
    private var _slot        :cpp.UInt32    = 0;
    private var _effects     :Array<cpp.UInt32>;
    private var _activeEffect:Int           = -1;  // -1 = none

    // -------------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------------

    private var _gain    :Float = 1.0;
    private var _looping :Bool  = true;
    private var _ready   :Bool  = false;

    // -------------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------------

    public function new(app:App) {
        super("TestOpenAL", app);
        _effects = [];
    }

    // -------------------------------------------------------------------------
    //  Lifecycle
    // -------------------------------------------------------------------------

    override public function init():Void {
        super.init();

        var log = app.log;

        // ------------------------------------------------------------------
        // Step 1 — open the default audio output device.
        // ------------------------------------------------------------------
        _device = OAL.openDevice(null);
        if (_device == null) {
            log.error(LogCategory.SYSTEM, "OAL.openDevice() failed");
            return;
        }

        // ------------------------------------------------------------------
        // Step 2 — create an OpenAL context.
        // ------------------------------------------------------------------
        _context = OAL.createContext(_device, null);
        if (_context == null) {
            log.error(LogCategory.SYSTEM, "OAL.createContext() failed");
            OAL.closeDevice(_device);
            _device = null;
            return;
        }

        // ------------------------------------------------------------------
        // Step 3 — make this context current.
        // ------------------------------------------------------------------
        if (!OAL.makeContextCurrent(_context)) {
            log.error(LogCategory.SYSTEM, "OAL.makeContextCurrent() failed");
            OAL.destroyContext(_context);
            OAL.closeDevice(_device);
            _context = null;
            _device  = null;
            return;
        }

        // ------------------------------------------------------------------
        // Step 4 — decode OGG → 16-bit PCM.
        // ------------------------------------------------------------------
        var pcm        :RawPointer<Int16> = null;
        var channels   :Int = 0;
        var sampleRate :Int = 0;

        var samplesPerCh = OAL.loadOgg(
            MUSIC_PATH,
            cpp.RawPointer.addressOf(pcm),
            cpp.RawPointer.addressOf(channels),
            cpp.RawPointer.addressOf(sampleRate)
        );

        if (samplesPerCh < 0 || pcm == null) {
            log.error(LogCategory.SYSTEM, "OAL.loadOgg() failed for: " + MUSIC_PATH);
            OAL.makeContextCurrent(null);
            OAL.destroyContext(_context);
            OAL.closeDevice(_device);
            _context = null;
            _device  = null;
            return;
        }

        log.debug(LogCategory.SYSTEM,
            'OGG decoded: $samplesPerCh samples/ch, $channels ch, ${sampleRate} Hz');

        // ------------------------------------------------------------------
        // Step 5 — allocate an OpenAL buffer.
        // ------------------------------------------------------------------
        _buffer = OAL.genBuffer();

        // ------------------------------------------------------------------
        // Step 6 — upload PCM into the buffer.
        // ------------------------------------------------------------------
        var format   = (channels == 2) ? OAL.FORMAT_STEREO16 : OAL.FORMAT_MONO16;
        var byteSize = samplesPerCh * channels * 2;
        OAL.bufferData(_buffer, format, pcm, byteSize, sampleRate);

        // ------------------------------------------------------------------
        // Step 7 — free the decoder heap allocation.
        // ------------------------------------------------------------------
        OAL.freeOggPcm(pcm);

        if (OAL.getError() != OAL.NO_ERROR) {
            log.error(LogCategory.SYSTEM, "alBufferData() failed");
            OAL.deleteBuffer(_buffer);
            OAL.makeContextCurrent(null);
            OAL.destroyContext(_context);
            OAL.closeDevice(_device);
            _buffer  = 0;
            _context = null;
            _device  = null;
            return;
        }

        // ------------------------------------------------------------------
        // Step 8 — allocate a source.
        // ------------------------------------------------------------------
        _source = OAL.genSource();

        // ------------------------------------------------------------------
        // Step 9-10 — attach buffer, configure looping and gain.
        // ------------------------------------------------------------------
        OAL.sourcei(_source, OAL.BUFFER,  _buffer);
        OAL.sourcei(_source, OAL.LOOPING, _looping ? OAL.TRUE : OAL.FALSE);
        OAL.sourcef(_source, OAL.GAIN,    _gain);

        // ------------------------------------------------------------------
        // EFX — try to initialise the effects extension.
        // ------------------------------------------------------------------
        _efxReady = OAL.efxInit(_device);
        if (_efxReady) {
            _initEffects();
            log.debug(LogCategory.SYSTEM, "EFX available — keys 1-9 toggle effects");
        } else {
            log.debug(LogCategory.SYSTEM, "EFX not available on this device");
        }

        // ------------------------------------------------------------------
        // Step 11 — start playback.
        // ------------------------------------------------------------------
        OAL.sourcePlay(_source);

        if (OAL.getError() != OAL.NO_ERROR) {
            log.error(LogCategory.SYSTEM, "alSourcePlay() failed");
        } else {
            log.debug(LogCategory.SYSTEM, "Playing: " + MUSIC_PATH);
        }

        _ready = true;
        log.debug(LogCategory.SYSTEM,
            "TestOpenALState ready — SPACE=play/pause  S=stop  +/-=volume  L=loop  1-9=effects");
    }

    // -------------------------------------------------------------------------
    //  EFX helpers
    // -------------------------------------------------------------------------

    private function _initEffects():Void {
        // Create one auxiliary effect slot.  The source is permanently wired
        // to this slot; toggling a key swaps which effect is loaded into it.
        _slot = OAL.efxGenSlot();
        OAL.efxSourceConnect(_source, _slot);

        // Pre-create all 9 effect objects with their tuned parameters.
        _effects = [];

        // 1 — Reverb (Room): short warm reflections
        var e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,        OAL.EFFECT_REVERB);
        OAL.efxEffectf(e, OAL.REVERB_DECAY_TIME,  2.0);
        OAL.efxEffectf(e, OAL.REVERB_DENSITY,     0.8);
        OAL.efxEffectf(e, OAL.REVERB_DIFFUSION,   0.8);
        OAL.efxEffectf(e, OAL.REVERB_LATE_GAIN,   1.5);
        _effects.push(e);

        // 2 — Reverb (Cathedral): huge hall, long tail
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,        OAL.EFFECT_REVERB);
        OAL.efxEffectf(e, OAL.REVERB_DECAY_TIME,  7.0);
        OAL.efxEffectf(e, OAL.REVERB_DENSITY,     1.0);
        OAL.efxEffectf(e, OAL.REVERB_DIFFUSION,   1.0);
        OAL.efxEffectf(e, OAL.REVERB_LATE_GAIN,   2.5);
        _effects.push(e);

        // 3 — Echo: noticeable stereo repeats
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,    OAL.EFFECT_ECHO);
        OAL.efxEffectf(e, OAL.ECHO_DELAY,     0.207);
        OAL.efxEffectf(e, OAL.ECHO_LRDELAY,   0.1);
        OAL.efxEffectf(e, OAL.ECHO_FEEDBACK,  0.75);
        OAL.efxEffectf(e, OAL.ECHO_SPREAD,    -1.0);
        _effects.push(e);

        // 4 — Chorus: shimmering, widened stereo image
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,      OAL.EFFECT_CHORUS);
        OAL.efxEffectf(e, OAL.CHORUS_RATE,      3.0);
        OAL.efxEffectf(e, OAL.CHORUS_DEPTH,     0.9);
        OAL.efxEffectf(e, OAL.CHORUS_FEEDBACK,  0.5);
        _effects.push(e);

        // 5 — Flanger: sweeping jet-engine comb filter
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,       OAL.EFFECT_FLANGER);
        OAL.efxEffectf(e, OAL.FLANGER_RATE,      3.0);
        OAL.efxEffectf(e, OAL.FLANGER_DEPTH,     1.0);
        OAL.efxEffectf(e, OAL.FLANGER_FEEDBACK,  0.7);
        _effects.push(e);

        // 6 — Distortion: clipped gritty overdrive
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,         OAL.EFFECT_DISTORTION);
        OAL.efxEffectf(e, OAL.DISTORTION_EDGE,     0.7);
        OAL.efxEffectf(e, OAL.DISTORTION_GAIN,     0.5);
        _effects.push(e);

        // 7 — Ring Modulator: metallic/robotic timbre at 440 Hz
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,          OAL.EFFECT_RING_MODULATOR);
        OAL.efxEffectf(e, OAL.RING_MOD_FREQUENCY,   440.0);
        OAL.efxEffecti(e, OAL.RING_MOD_WAVEFORM,    OAL.RING_MOD_SINUSOID);
        _effects.push(e);

        // 8 — Pitch Shifter: transpose up by exactly one octave
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,        OAL.EFFECT_PITCH_SHIFTER);
        OAL.efxEffecti(e, OAL.PITCH_COARSE_TUNE,  12);  // +12 semitones = +1 octave
        _effects.push(e);

        // 9 — Autowah: envelope-following resonant filter sweep
        e = OAL.efxGenEffect();
        OAL.efxEffecti(e, OAL.EFFECT_TYPE,           OAL.EFFECT_AUTOWAH);
        OAL.efxEffectf(e, OAL.AUTOWAH_ATTACK_TIME,   0.01);
        OAL.efxEffectf(e, OAL.AUTOWAH_RESONANCE,     1000.0);
        OAL.efxEffectf(e, OAL.AUTOWAH_PEAK_GAIN,     30.0);
        _effects.push(e);
    }

    private function _toggleEffect(index:Int):Void {
        if (!_efxReady) return;

        if (_activeEffect == index) {
            // Same key pressed again — turn the effect off
            OAL.efxSlotEffect(_slot, 0);
            _activeEffect = -1;
            app.log.debug(LogCategory.SYSTEM, "Effect: OFF");
        } else {
            // Switch to the chosen effect
            OAL.efxSlotEffect(_slot, _effects[index]);
            _activeEffect = index;
            app.log.debug(LogCategory.SYSTEM, "Effect: " + EFFECT_NAMES[index]);
        }
    }

    // -------------------------------------------------------------------------
    //  Update
    // -------------------------------------------------------------------------

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        if (!_ready) return;

        var kb  = app.input.keyboard;
        var log = app.log;

        // SPACE — toggle play / pause
        if (kb.released(Keycode.SPACE)) {
            var state = OAL.getSourcei(_source, OAL.SOURCE_STATE);
            if (state == OAL.PAUSED) {
                OAL.sourcePlay(_source);
                log.debug(LogCategory.SYSTEM, "Resumed");
            } else if (state == OAL.PLAYING) {
                OAL.sourcePause(_source);
                log.debug(LogCategory.SYSTEM, "Paused");
            } else {
                OAL.sourceRewind(_source);
                OAL.sourcePlay(_source);
                log.debug(LogCategory.SYSTEM, "Restarted");
            }
        }

        // S — stop and rewind
        if (kb.released(Keycode.S)) {
            OAL.sourceStop(_source);
            OAL.sourceRewind(_source);
            log.debug(LogCategory.SYSTEM, "Stopped & rewound");
        }

        // + / = — volume up
        if (kb.released(Keycode.EQUALS)) {
            _gain = Math.min(_gain + GAIN_STEP, GAIN_MAX);
            OAL.sourcef(_source, OAL.GAIN, _gain);
            log.debug(LogCategory.SYSTEM, "Gain: " + _gain);
        }

        // - — volume down
        if (kb.released(Keycode.MINUS)) {
            _gain = Math.max(_gain - GAIN_STEP, GAIN_MIN);
            OAL.sourcef(_source, OAL.GAIN, _gain);
            log.debug(LogCategory.SYSTEM, "Gain: " + _gain);
        }

        // L — toggle looping
        if (kb.released(Keycode.L)) {
            _looping = !_looping;
            OAL.sourcei(_source, OAL.LOOPING, _looping ? OAL.TRUE : OAL.FALSE);
            log.debug(LogCategory.SYSTEM, "Looping: " + (_looping ? "ON" : "OFF"));
        }

        // 1-9 — toggle EFX effects
        if (kb.released(Keycode.KEY_1)) _toggleEffect(0);
        if (kb.released(Keycode.KEY_2)) _toggleEffect(1);
        if (kb.released(Keycode.KEY_3)) _toggleEffect(2);
        if (kb.released(Keycode.KEY_4)) _toggleEffect(3);
        if (kb.released(Keycode.KEY_5)) _toggleEffect(4);
        if (kb.released(Keycode.KEY_6)) _toggleEffect(5);
        if (kb.released(Keycode.KEY_7)) _toggleEffect(6);
        if (kb.released(Keycode.KEY_8)) _toggleEffect(7);
        if (kb.released(Keycode.KEY_9)) _toggleEffect(8);
    }

    // -------------------------------------------------------------------------
    //  Release — always mirror init() in reverse order
    // -------------------------------------------------------------------------

    override public function release():Void {
        super.release();

        if (!_ready) return;

        // EFX cleanup — disconnect source, delete slot, delete all effect objects
        if (_efxReady) {
            OAL.efxSourceDisconnect(_source);
            OAL.efxDeleteSlot(_slot);
            _slot = 0;
            for (e in _effects) OAL.efxDeleteEffect(e);
            _effects  = [];
            _efxReady = false;
        }

        OAL.sourceStop(_source);
        OAL.deleteSource(_source);
        _source = 0;

        OAL.deleteBuffer(_buffer);
        _buffer = 0;

        OAL.makeContextCurrent(null);
        OAL.destroyContext(_context);
        _context = null;

        OAL.closeDevice(_device);
        _device = null;

        _ready = false;
        app.log.debug(LogCategory.SYSTEM, "TestOpenALState released");
    }
}
