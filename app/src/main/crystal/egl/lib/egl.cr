# <EGL/egl.h>

require "android_ndk/lib/native_window"

@[Link("EGL")]
module EGL
  lib Lib
    alias Boolean = LibC::UInt
    alias Display = Void*
    alias Int = Int32
    alias Config = Void*
    alias Surface = Void*
    alias Context = Void*

    alias NativeDisplayType = Void*
    alias NativePixmapType = Void*
    alias NativeWindowType = AndroidNDK::Lib::ANativeWindow*

    EGL_DEFAULT_DISPLAY = NativeDisplayType.null

    WINDOW_BIT = 0x0004

    EGL_OPENGL_ES2_BIT =     0x0004
    EGL_OPENGL_ES3_BIT = 0x00000040

    BLUE_SIZE        = 0x3022
    GREEN_SIZE       = 0x3023
    RED_SIZE         = 0x3024
    DEPTH_SIZE       = 0x3025
    NATIVE_VISUAL_ID = 0x302E
    SURFACE_TYPE     = 0x3033
    NONE             = 0x3038
    RENDERABLE_TYPE  = 0x3040
    HEIGHT           = 0x3056
    WIDTH            = 0x3057

    CONTEXT_CLIENT_VERSION = 0x3098

    fun choose_config = eglChooseConfig(dpy : Display, attrib_list : Int*, configs : Config*, config_size : Int, num_config : Int*) : Boolean
    fun copy_buffers = eglCopyBuffers(dpy : Display, surface : Surface, target : NativePixmapType) : Boolean
    fun create_context = eglCreateContext(dpy : Display, config : Config, share_context : Context, attrib_list : Int*) : Context
    fun create_pbuffer_surface = eglCreatePbufferSurface(dpy : Display, config : Config, attrib_list : Int*) : Surface
    fun create_pixmap_surface = eglCreatePixmapSurface(dpy : Display, config : Config, pixmap : NativePixmapType, attrib_list : Int*) : Surface
    fun create_window_surface = eglCreateWindowSurface(dpy : Display, config : Config, win : NativeWindowType, attrib_list : Int*) : Surface
    fun destroy_context = eglDestroyContext(dpy : Display, ctx : Context) : Boolean
    fun destroy_surface = eglDestroySurface(dpy : Display, surface : Surface) : Boolean
    fun get_config_attrib = eglGetConfigAttrib(dpy : Display, config : Config, attribute : Int, value : Int*) : Boolean
    fun get_configs = eglGetConfigs(dpy : Display, configs : Config*, config_size : Int, num_config : Int*) : Boolean
    fun get_current_display = eglGetCurrentDisplay : Display
    fun get_current_surface = eglGetCurrentSurface(readdraw : Int) : Surface
    fun get_display = eglGetDisplay(display_id : NativeDisplayType) : Display
    fun get_error = eglGetError : Int
    fun get_proc_address = eglGetProcAddress(procname : LibC::Char*) : Void*
    fun initialize = eglInitialize(dpy : Display, major : Int*, minor : Int*) : Boolean
    fun make_current = eglMakeCurrent(dpy : Display, draw : Surface, read : Surface, ctx : Context) : Boolean
    fun query_context = eglQueryContext(dpy : Display, ctx : Context, attribute : Int, value : Int*) : Boolean
    fun query_string = eglQueryString(dpy : Display, name : Int) : LibC::Char*
    fun query_surface = eglQuerySurface(dpy : Display, surface : Surface, attribute : Int, value : Int*) : Boolean
    fun swap_buffers = eglSwapBuffers(dpy : Display, surface : Surface) : Boolean
    fun terminate = eglTerminate(dpy : Display) : Boolean
    fun wait_gl = eglWaitGL : Boolean
    fun wait_native = eglWaitNative(engine : Int) : Boolean
  end
end
