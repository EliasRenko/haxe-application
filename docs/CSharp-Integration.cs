using System;
using System.Runtime.InteropServices;
using System.Threading;

/// <summary>
/// Haxe Engine DLL Wrapper for C#
/// This class provides P/Invoke declarations for the Haxe engine exported from Main-debug.dll
/// 
/// IMPORTANT: You must initialize the Haxe runtime before calling any Engine functions!
/// </summary>
public class HaxeEngine
{
    private const string DLL_NAME = "Main-debug.dll";
    
    // ===== Haxe Runtime Initialization =====
    // These MUST be called before using the engine
    
    /// <summary>
    /// Initialize the Haxe runtime. MUST be called first before any other function!
    /// </summary>
    /// <returns>NULL (IntPtr.Zero) on success, error message pointer on failure</returns>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern IntPtr HxcppInit();
    
    /// <summary>
    /// Attach the current thread to Haxe GC. Call this at the start of each thread that uses Haxe.
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void HxcppThreadAttach();
    
    /// <summary>
    /// Detach the current thread from Haxe GC. Call this before thread exits.
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void HxcppThreadDetach();
    
    /// <summary>
    /// Manually trigger garbage collection
    /// </summary>
    /// <param name="major">true for major collection, false for minor</param>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void HxcppGarbageCollect(bool major);
    
    // ===== Engine API =====
    
    /// <summary>
    /// Initialize the game engine (creates window, loads resources, etc.)
    /// </summary>
    /// <returns>1 on success, 0 on failure</returns>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern int EngineInit();
    
    /// <summary>
    /// Update the engine for one frame
    /// </summary>
    /// <param name="deltaTime">Time elapsed since last frame in seconds</param>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void EngineUpdate(float deltaTime);
    
    /// <summary>
    /// Render the current frame
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void EngineRender();
    
    /// <summary>
    /// Swap window buffers (present the rendered frame to screen)
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void EngineSwapBuffers();
    
    /// <summary>
    /// Shutdown the engine and release resources
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void EngineShutdown();
    
    /// <summary>
    /// Load a game state
    /// </summary>
    /// <param name="stateIndex">State ID (0=CollisionTest, 1=UITest, etc.)</param>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void EngineLoadState(int stateIndex);
    
    /// <summary>
    /// Check if the engine is still running
    /// </summary>
    /// <returns>1 if running, 0 if stopped</returns>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern int EngineIsRunning();
    
    /// <summary>
    /// Get the current window width
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern int EngineGetWindowWidth();
    
    /// <summary>
    /// Get the current window height
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern int EngineGetWindowHeight();
    
    /// <summary>
    /// Set the window size
    /// </summary>
    [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
    public static extern void EngineSetWindowSize(int width, int height);
}

/// <summary>
/// Example usage of the Haxe Engine from C#
/// </summary>
public class Program
{
    static void Main(string[] args)
    {
        // STEP 1: Initialize Haxe runtime (REQUIRED!)
        IntPtr errorPtr = HaxeEngine.HxcppInit();
        if (errorPtr != IntPtr.Zero)
        {
            string error = Marshal.PtrToStringAnsi(errorPtr);
            Console.WriteLine($"Failed to initialize Haxe runtime: {error}");
            return;
        }
        Console.WriteLine("Haxe runtime initialized successfully");
        
        // STEP 2: Attach current thread to Haxe GC
        HaxeEngine.HxcppThreadAttach();
        
        try
        {
            // STEP 3: Initialize the engine
            if (HaxeEngine.EngineInit() != 1)
            {
                Console.WriteLine("Failed to initialize engine");
                return;
            }
            Console.WriteLine("Engine initialized successfully!");
            
            // STEP 4: Load a game state (optional)
            HaxeEngine.EngineLoadState(0); // Load CollisionTestState
            
            // STEP 5: Game loop
            Console.WriteLine("Starting game loop...");
            float deltaTime = 0.016f; // ~60 FPS
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            
            while (HaxeEngine.EngineIsRunning() == 1)
            {
                // Calculate actual delta time
                deltaTime = (float)stopwatch.Elapsed.TotalSeconds;
                stopwatch.Restart();
                
                // Update, render, and present
                HaxeEngine.EngineUpdate(deltaTime);
                HaxeEngine.EngineRender();
                HaxeEngine.EngineSwapBuffers();
                
                // Limit to ~60 FPS
                Thread.Sleep(16);
                
                // Optional: Press ESC to quit (you'll need to handle this in Haxe side)
            }
            
            Console.WriteLine("Game loop ended");
        }
        finally
        {
            // STEP 6: Cleanup
            HaxeEngine.EngineShutdown();
            
            // STEP 7: Detach thread from Haxe GC
            HaxeEngine.HxcppThreadDetach();
            
            // Optional: Trigger final GC
            HaxeEngine.HxcppGarbageCollect(true);
        }
        
        Console.WriteLine("Engine shut down successfully");
    }
}

/// <summary>
/// Example with WinForms integration
/// </summary>
public class GameForm : System.Windows.Forms.Form
{
    private Thread gameThread;
    private volatile bool running = false;
    
    public GameForm()
    {
        this.Text = "Haxe Engine";
        this.Width = 800;
        this.Height = 600;
        this.FormClosed += GameForm_FormClosed;
    }
    
    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        
        // Initialize Haxe runtime on form load
        IntPtr errorPtr = HaxeEngine.HxcppInit();
        if (errorPtr != IntPtr.Zero)
        {
            string error = Marshal.PtrToStringAnsi(errorPtr);
            System.Windows.Forms.MessageBox.Show($"Failed to initialize: {error}");
            this.Close();
            return;
        }
        
        // Start game in separate thread
        gameThread = new Thread(GameLoop);
        gameThread.IsBackground = true;
        running = true;
        gameThread.Start();
    }
    
    private void GameLoop()
    {
        // Attach this thread to Haxe GC
        HaxeEngine.HxcppThreadAttach();
        
        try
        {
            // Initialize engine
            if (HaxeEngine.EngineInit() != 1)
            {
                this.Invoke((Action)(() => {
                    System.Windows.Forms.MessageBox.Show("Failed to initialize engine");
                    this.Close();
                }));
                return;
            }
            
            // Load default state
            HaxeEngine.EngineLoadState(0);
            
            // Game loop
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            while (running && HaxeEngine.EngineIsRunning() == 1)
            {
                float deltaTime = (float)stopwatch.Elapsed.TotalSeconds;
                stopwatch.Restart();
                
                HaxeEngine.EngineUpdate(deltaTime);
                HaxeEngine.EngineRender();
                HaxeEngine.EngineSwapBuffers();
                
                Thread.Sleep(16); // ~60 FPS
            }
        }
        finally
        {
            HaxeEngine.EngineShutdown();
            HaxeEngine.HxcppThreadDetach();
        }
    }
    
    private void GameForm_FormClosed(object sender, System.Windows.Forms.FormClosedEventArgs e)
    {
        running = false;
        if (gameThread != null && gameThread.IsAlive)
        {
            gameThread.Join(1000); // Wait max 1 second for clean shutdown
        }
    }
}
