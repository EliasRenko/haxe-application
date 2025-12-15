using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SDK
{
    public partial class Form1 : Form
    {
        [DllImport("Main-debug.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void EngineTestConsole();

        [DllImport("user32.dll")]
        static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

        [DllImport("user32.dll")]
        static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

        private bool engineInitialized = false;
        private Stopwatch deltaTimer = new Stopwatch();
        private System.Windows.Forms.Timer renderTimer;
        private IntPtr sdlWindowHandle = IntPtr.Zero;

        public Form1()
        {
            InitializeComponent();
            
            // Enable double buffering on the panel to reduce flicker
            // panel1.SetStyle(ControlStyles.OptimizedDoubleBuffer, true);
            // panel1.SetStyle(ControlStyles.AllPaintingInWmPaint, true);
            // panel1.SetStyle(ControlStyles.UserPaint, true);
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            // No initialization needed here
        }

        private void btnRunEngine_Click(object sender, EventArgs e)
        {
            if (engineInitialized)
            {
                MessageBox.Show("Engine is already running!", "Info",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            try
            {
                // Test console first
                EngineTestConsole();

                // Initialize engine normally - SDL creates its own window
                if (HaxeEngine.EngineInit() != 1)
                {
                    MessageBox.Show("Failed to initialize engine", "Error",
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                Console.WriteLine("Engine initialized successfully!");

                // Get the SDL window handle
                sdlWindowHandle = HaxeEngine.EngineGetWindowHandle();
                if (sdlWindowHandle == IntPtr.Zero)
                {
                    MessageBox.Show("Failed to get SDL window handle", "Error",
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                // Set SDL window as child of panel
                SetParent(sdlWindowHandle, panel1.Handle);
                MoveWindow(sdlWindowHandle, 0, 0, panel1.Width, panel1.Height, true);

                // Load default state (CollisionTestState)
                HaxeEngine.EngineLoadState(0);

                engineInitialized = true;
                btnRunEngine.Enabled = false;

                // Start delta timer
                deltaTimer.Start();

                // Start render loop on UI thread - runs continuously
                renderTimer = new System.Windows.Forms.Timer();
                renderTimer.Interval = 1; // Run as fast as possible, limited by VSync
                renderTimer.Tick += RenderFrame;
                renderTimer.Start();

                // Handle panel resize
                panel1.Resize += Panel_Resize;
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Engine initialization error: {ex.Message}", "Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private void RenderFrame(object sender, EventArgs e)
        {
            if (!engineInitialized) return;

            // Calculate actual delta time
            float deltaTime = (float)deltaTimer.Elapsed.TotalSeconds;
            deltaTimer.Restart();

            // Update, render, and present - all on UI thread
            HaxeEngine.EngineUpdate(deltaTime);
            HaxeEngine.EngineRender();
            HaxeEngine.EngineSwapBuffers();
        }

        private void Panel_Resize(object sender, EventArgs e)
        {
            if (engineInitialized && sdlWindowHandle != IntPtr.Zero)
            {
                // Resize the SDL window to match the panel
                MoveWindow(sdlWindowHandle, 0, 0, panel1.Width, panel1.Height, true);
                HaxeEngine.EngineSetWindowSize(panel1.Width, panel1.Height);
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            base.OnFormClosing(e);

            if (renderTimer != null)
            {
                renderTimer.Stop();
                renderTimer.Dispose();
            }

            if (engineInitialized)
            {
                HaxeEngine.EngineShutdown();
                engineInitialized = false;
            }
        }
    }

    /// <summary>
    /// Haxe Engine DLL wrapper
    /// </summary>
    public static class HaxeEngine
    {
        private const string DLL_NAME = "Main-debug.dll";

        // ===== Haxe Runtime Initialization =====
        // These are no longer needed - EngineInitWithWindow handles everything

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
        public static extern int EngineInitWithWindow(IntPtr hwnd);

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

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr EngineGetWindowHandle();
    }
}
