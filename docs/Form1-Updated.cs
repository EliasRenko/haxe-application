using System.Runtime.InteropServices;
using System.Threading;

namespace SDK {
    public partial class Form1 : Form {

        // Windows API for window manipulation
        [DllImport("user32.dll")]
        private static extern IntPtr SetWindowPos(IntPtr handle, IntPtr handleAfter, 
            int x, int y, int cx, int cy, uint flags);

        [DllImport("user32.dll")]
        private static extern IntPtr SetParent(IntPtr child, IntPtr newParent);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr handle, int command);

        private bool engineInitialized = false;
        private IntPtr sdlWindowHandle = IntPtr.Zero;
        private Thread gameThread;
        private volatile bool running = false;

        public Form1() {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e) {
            // No initialization needed here - EngineInit() handles everything
        }

        private void btnRunEngine_Click(object sender, EventArgs e) {
            if (engineInitialized) {
                MessageBox.Show("Engine is already running!", "Info", 
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            // Start engine in separate thread
            gameThread = new Thread(GameLoop);
            gameThread.IsBackground = true;
            running = true;
            engineInitialized = true;
            gameThread.Start();

            // Disable the button to prevent multiple starts
            btnRunEngine.Enabled = false;
        }

        private void GameLoop() {
            try {
                // EngineInit now handles both hxcpp initialization and thread attachment
                if (HaxeEngine.EngineInit() != 1) {
                    this.Invoke((Action)(() => {
                        MessageBox.Show("Failed to initialize engine", "Error", 
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
                        btnRunEngine.Enabled = true;
                    }));
                    engineInitialized = false;
                    return;
                }

                Console.WriteLine("Engine initialized successfully!");

                // Load default state (CollisionTestState)
                HaxeEngine.EngineLoadState(0);

                // Game loop
                var stopwatch = System.Diagnostics.Stopwatch.StartNew();
                while (running && HaxeEngine.EngineIsRunning() == 1) {
                    // Calculate actual delta time
                    float deltaTime = (float)stopwatch.Elapsed.TotalSeconds;
                    stopwatch.Restart();

                    // Update, render, and present
                    HaxeEngine.EngineUpdate(deltaTime);
                    HaxeEngine.EngineRender();
                    HaxeEngine.EngineSwapBuffers();

                    // Limit to ~60 FPS
                    Thread.Sleep(16);
                }

                Console.WriteLine("Game loop ended");
            }
            catch (Exception ex) {
                Console.WriteLine($"Game loop error: {ex.Message}");
                this.Invoke((Action)(() => {
                    MessageBox.Show($"Engine error: {ex.Message}", "Error", 
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                }));
            }
            finally {
                // Cleanup
                HaxeEngine.EngineShutdown();
                
                engineInitialized = false;
                
                // Re-enable button on UI thread
                this.Invoke((Action)(() => {
                    btnRunEngine.Enabled = true;
                }));
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e) {
            base.OnFormClosing(e);

            // Stop the game loop
            running = false;

            // Wait for game thread to finish
            if (gameThread != null && gameThread.IsAlive) {
                gameThread.Join(2000); // Wait max 2 seconds
            }
        }

        protected override void OnResize(EventArgs e) {
            base.OnResize(e);

            if (sdlWindowHandle != IntPtr.Zero) {
                SetWindowPos(sdlWindowHandle, IntPtr.Zero, 0, 0,
                    this.ClientSize.Width, this.ClientSize.Height, 0x0004);
            }
            
            // Update engine window size if initialized
            if (engineInitialized) {
                HaxeEngine.EngineSetWindowSize(this.ClientSize.Width, this.ClientSize.Height);
            }
        }
    }

    /// <summary>
    /// Haxe Engine DLL wrapper - place this in a separate HaxeEngine.cs file
    /// </summary>
    public static class HaxeEngine {
        private const string DLL_NAME = "Main-debug.dll";

        // ===== Haxe Runtime Initialization =====
        
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr HxcppInit();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void HxcppThreadAttach();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void HxcppThreadDetach();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void HxcppGarbageCollect(bool major);

        // ===== Engine API =====

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int EngineInit();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineUpdate(float deltaTime);

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineRender();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineSwapBuffers();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineShutdown();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineLoadState(int stateIndex);

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int EngineIsRunning();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int EngineGetWindowWidth();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int EngineGetWindowHeight();

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineSetWindowSize(int width, int height);
    }
}
