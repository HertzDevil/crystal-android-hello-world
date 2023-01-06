require "android_ndk/on_create"
require "android_ndk/native_app_glue"
require "android_ndk/util/log"
require "./egl/lib/egl"
require "opengl"

require "crystal/system/thread"
require "log"

require "./matrix4"

Log.setup "*", level: :trace, backend: AndroidNDK::Util::LogBackend.new

LOG = ::Log.for("NATIVE_ACTIVITY")
LOG.info { "HELLO FROM CRYSTAL" }

GL_VERTEX_SHADER_SRC   = {{ read_file "#{__DIR__}/vertex.glsl" }}
GL_FRAGMENT_SHADER_SRC = {{ read_file "#{__DIR__}/fragment.glsl" }}

record Vertex, x : Float32, y : Float32, z : Float32, nx : Float32, ny : Float32, nz : Float32

def read_stl(f : IO) : Slice(Vertex)
  header = uninitialized UInt8[80]
  f.read_fully(header.to_slice)

  count = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
  slice = Slice.new(Pointer(Vertex).malloc(count * 3), count * 3)
  ptr = slice.to_unsafe.appender

  count.times do |i|
    xn = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    yn = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    zn = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)

    x1 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    y1 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    z1 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)

    x2 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    y2 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    z2 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)

    x3 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    y3 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)
    z3 = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian).unsafe_as(Float32)

    f.read_bytes(UInt16, IO::ByteFormat::LittleEndian) # attributes

    ptr << Vertex.new(x1, y1, z1, xn, yn, zn)
    ptr << Vertex.new(x2, y2, z2, xn, yn, zn)
    ptr << Vertex.new(x3, y3, z3, xn, yn, zn)
  end

  Slice.new(slice.to_unsafe, slice.size, read_only: true)
end

class MyApp < AndroidNDK::NativeAppGlue::App
  getter! glue : AndroidNDK::NativeAppGlue

  getter display = EGL::Lib::Display.null
  getter surface = EGL::Lib::Surface.null
  getter context = EGL::Lib::Context.null

  getter width : Int32 = 0
  getter height : Int32 = 0

  @gl_program = LibGL::UInt.zero
  @vbo_id = LibGL::UInt.zero

  DISTANCE = 4_f32

  @model_matrix : Matrix4F32 = Matrix4F32.identity
  @view_matrix : Matrix4F32 = Matrix4F32.identity
  @perspective_matrix : Matrix4F32 = Matrix4F32.identity

  @d_yaw = -0.5_f32
  @d_pitch = -0.5_f32
  @last : {Float32, Float32}?

  @stl = Slice(Vertex).empty

  def run(glue : AndroidNDK::NativeAppGlue)
    LOG.trace { "INSIDE run" }

    @glue = glue

    LOG.debug { "internal_data_path = #{glue.activity.internal_data_path}" }
    LOG.debug { "external_data_path = #{glue.activity.external_data_path}" }
    LOG.debug { "sdk_version = #{glue.activity.sdk_version}" }
    LOG.debug { "obb_path = #{glue.activity.obb_path}" }

    @stl = glue.activity.asset_manager.open("Regular_icosahedron.stl") do |f|
      read_stl(f)
    end
    LOG.debug { @stl.size }

    t0 = Time.monotonic

    while true
      while (result = AndroidNDK::Looper.poll_all(0)).is_a?(AndroidNDK::Looper::PollFd)
        case result.ident
        when AndroidNDK::NativeAppGlue::LOOPER_ID_MAIN, AndroidNDK::NativeAppGlue::LOOPER_ID_INPUT
          glue.process(result.ident)
        end

        if glue.destroy_requested?
          term_display
          return
        end
      end

      t1 = Time.monotonic
      dt = (t1 - t0).total_seconds
      t0 = t1

      update(dt)
      # LOG.trace &.emit("REDRAW", dt: dt)
      draw_frame
    end
  end

  private def update(dt)
    @model_matrix = Matrix4F32.rotate(x: @d_pitch * dt) * Matrix4F32.rotate(y: @d_yaw * dt) * @model_matrix

    if @last
      @d_yaw = @d_pitch = 0_f32
    else
      restart = @d_yaw == 0 && @d_pitch == 0
      @d_yaw = decelerate(@d_yaw, restart)
      @d_pitch = decelerate(@d_pitch, restart)
    end
  end

  private def decelerate(value, restart)
    if restart
      0.005_f32 * (rand >= 0.5 ? 1 : -1)
    elsif value.abs < 0.5
      value * 1.01_f32
    else
      {value.abs * 0.99_f32, 0.5_f32}.max * value.sign
    end
  end

  def on_app_cmd(glue : AndroidNDK::NativeAppGlue, cmd : AndroidNDK::NativeAppGlue::Command)
    LOG.debug { "cmd = #{cmd.inspect}" }

    case cmd
    when .init_window?
      init_display

      LOG.info { "GL_VENDOR = #{String.new(LibGL.get_string(LibGL::StringName::Vendor))}" }
      LOG.info { "GL_RENDERER = #{String.new(LibGL.get_string(LibGL::StringName::Renderer))}" }
      LOG.info { "GL_VERSION = #{String.new(LibGL.get_string(LibGL::StringName::Version))}" }
      LOG.info { "GL_EXTENSIONS = #{String.new(LibGL.get_string(LibGL::StringName::Extensions))}" }
      LOG.info { "GL_SHADING_LANGUAGE_VERSION = #{String.new(LibGL.get_string(LibGL::StringName::ShadingLanguageVersion))}" }

      if @gl_program.zero?
        @gl_program = compile_shader_program(GL_VERTEX_SHADER_SRC, GL_FRAGMENT_SHADER_SRC)
        raise "Unable to compile shader program!" if @gl_program.zero?
      end

      if @vbo_id.zero?
        LibGL.gen_buffers(1, pointerof(@vbo_id))
        LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, @vbo_id)
        LibGL.buffer_data(LibGL::BufferTargetARB::ArrayBuffer, @stl.bytesize, @stl, LibGL::BufferUsageARB::StaticDraw)
      end

      @view_matrix = Matrix4F32.look_at(
        eye: Vector3F32.new(0, 0, DISTANCE),
        center: Vector3F32.new(0, 0, 0),
        up: Vector3F32.new(0, 1, 0),
      )

      aspect_ratio = (@height / @width).to_f32
      @perspective_matrix = Matrix4F32.frustum(-1_f32, 1_f32, -aspect_ratio, aspect_ratio, DISTANCE - 1, DISTANCE + 1)

      draw_frame
    end
  end

  def on_input_event(glue : AndroidNDK::NativeAppGlue, event : AndroidNDK::InputEvent) : Bool
    case event
    when AndroidNDK::MotionEvent
      case event.action[0]
      when .down?
        @last = {event.x(0), event.y(0)}
        return true
      when .move?
        depth = @width.to_f32 / DISTANCE
        x = event.x(0)
        y = event.y(0)
        last_x, last_y = @last.not_nil!
        @d_yaw = 50_f32 * (Math.atan2(x - width.to_f32 / 2, depth) - Math.atan2(last_x - width.to_f32 / 2, depth))
        @d_pitch = 50_f32 * (Math.atan2(y - height.to_f32 / 2, depth) - Math.atan2(last_y - height.to_f32 / 2, depth))
        @last = {x, y}
        return true
      when .up?
        @last = nil
        return true
      end
    end

    false
  end

  private def load_shader(type : LibGL::ShaderType, source : String)
    shader = LibGL.create_shader(type)
    if shader != 0
      source_ptr = source.to_unsafe
      source_len = source.bytesize
      LibGL.shader_source(shader, 1, pointerof(source_ptr), pointerof(source_len))
      LibGL.compile_shader(shader)

      LibGL.get_shader_iv(shader, LibGL::ShaderParameterName::CompileStatus, out status)
      if status == 0
        LibGL.get_shader_iv(shader, LibGL::ShaderParameterName::InfoLogLength, out info_len)
        if info_len != 0
          buf = Bytes.new(info_len)
          LibGL.get_shader_info_log(shader, info_len, nil, buf)
          LOG.error { "Could not compile shader: #{String.new(buf[..-2]).inspect}" }
        end
        LibGL.delete_shader(shader)
        return LibGL::UInt.zero
      end
    end
    shader
  end

  private def compile_shader_program(vertex_src : String, fragment_src : String)
    vertex_shader = load_shader(LibGL::ShaderType::VertexShader, vertex_src)
    LOG.debug { "vertex_shader = #{vertex_shader}" }
    return LibGL::UInt.zero if vertex_shader == 0

    fragment_shader = load_shader(LibGL::ShaderType::FragmentShader, fragment_src)
    LOG.debug { "fragment_shader = #{fragment_shader}" }
    return LibGL::UInt.zero if fragment_shader == 0

    program = LibGL.create_program
    if program != 0
      LibGL.attach_shader(program, vertex_shader)
      LibGL.attach_shader(program, fragment_shader)
      LibGL.link_program(program)

      LibGL.get_program_iv(program, LibGL::ProgramPropertyARB::LinkStatus, out status)
      if status == 0
        LibGL.get_program_iv(program, LibGL::ProgramPropertyARB::InfoLogLength, out info_len)
        if info_len != 0
          buf = Bytes.new(info_len)
          LibGL.get_program_info_log(program, info_len, nil, buf)
          LOG.error { "Could not link program: #{String.new(buf[..-2]).inspect}" }
        end
        LibGL.delete_program(program)
        return LibGL::UInt.zero
      end
    end
    program
  end

  private def init_display : Bool
    display = EGL::Lib.get_display(EGL::Lib::EGL_DEFAULT_DISPLAY)
    EGL::Lib.initialize(display, nil, nil)

    attribs = [
      EGL::Lib::RENDERABLE_TYPE, EGL::Lib::EGL_OPENGL_ES3_BIT,
      EGL::Lib::SURFACE_TYPE, EGL::Lib::WINDOW_BIT,
      EGL::Lib::BLUE_SIZE, 8,
      EGL::Lib::GREEN_SIZE, 8,
      EGL::Lib::RED_SIZE, 8,
      EGL::Lib::NONE,
    ] of EGL::Lib::Int
    EGL::Lib.choose_config(display, attribs, nil, 0, out num_configs)
    supported_configs = Slice(EGL::Lib::Config).new(num_configs) { EGL::Lib::Config.null }
    EGL::Lib.choose_config(display, attribs, supported_configs, num_configs, pointerof(num_configs))
    config = supported_configs.find do |cfg|
      next unless EGL::Lib.get_config_attrib(display, cfg, EGL::Lib::RED_SIZE, out r) != 0
      next unless EGL::Lib.get_config_attrib(display, cfg, EGL::Lib::GREEN_SIZE, out g) != 0
      next unless EGL::Lib.get_config_attrib(display, cfg, EGL::Lib::BLUE_SIZE, out b) != 0
      next unless EGL::Lib.get_config_attrib(display, cfg, EGL::Lib::DEPTH_SIZE, out d) != 0
      r == 8 && g == 8 && b == 8 && d == 0
    end || supported_configs.first?

    unless config
      LOG.warn { "Unable to initialize EGLConfig" }
      return false
    end

    EGL::Lib.get_config_attrib(display, config, EGL::Lib::NATIVE_VISUAL_ID, out format)
    surface = EGL::Lib.create_window_surface(display, config, glue.window.not_nil!, nil)

    attribs = [
      EGL::Lib::CONTEXT_CLIENT_VERSION, 3,
      EGL::Lib::NONE,
    ] of EGL::Lib::Int
    context = EGL::Lib.create_context(display, config, nil, attribs)

    if EGL::Lib.make_current(display, surface, surface, context) == 0
      LOG.warn { "Unable to eglMakeCurrent" }
      return false
    end

    EGL::Lib.query_surface(display, surface, EGL::Lib::WIDTH, out w)
    EGL::Lib.query_surface(display, surface, EGL::Lib::HEIGHT, out h)
    @display = display
    @context = context
    @surface = surface
    @width = w
    @height = h
    LOG.info { "display = #{display}" }
    LOG.info { "context = #{context}" }
    LOG.info { "surface = #{surface}" }
    LOG.info { "width = #{@width}" }
    LOG.info { "height = #{@height}" }

    LibGL.enable(LibGL::EnableCap::CullFace)
    LibGL.disable(LibGL::EnableCap::DepthTest)
    true
  end

  private def term_display
    if @display
      EGL::Lib.make_current(@display, EGL::Lib::Surface.null, EGL::Lib::Surface.null, EGL::Lib::Context.null)
      EGL::Lib.destroy_context(@display, @context) if @context
      EGL::Lib.destroy_surface(@display, @surface) if @surface
      EGL::Lib.terminate(@display)
    end
    @display = EGL::Lib::Display.null
    @context = EGL::Lib::Context.null
    @surface = EGL::Lib::Surface.null
  end

  private def draw_frame
    return unless display = @display

    LibGL.clear_color(1.0, 1.0, 1.0, 1.0)
    LibGL.clear(LibGL::ClearBufferMask::ColorBuffer | LibGL::ClearBufferMask::DepthBuffer)

    LibGL.use_program(@gl_program)

    LibGL.uniform_matrix4_fv(LibGL.get_uniform_location(@gl_program, "uPerspectiveMatrix"), 1, LibGL::Boolean::True, @perspective_matrix)
    LibGL.uniform_matrix4_fv(LibGL.get_uniform_location(@gl_program, "uViewMatrix"), 1, LibGL::Boolean::True, @view_matrix)
    LibGL.uniform_matrix4_fv(LibGL.get_uniform_location(@gl_program, "uModelMatrix"), 1, LibGL::Boolean::True, @model_matrix)
    LibGL.uniform_3f(LibGL.get_uniform_location(@gl_program, "uDiffuseLightDirection"), -5, 5, 20)
    LibGL.uniform_3f(LibGL.get_uniform_location(@gl_program, "uDiffuseLightColor"), 140 / 255, 140 / 255, 140 / 255)
    LibGL.uniform_1f(LibGL.get_uniform_location(@gl_program, "uContrast"), 0.9)

    v_position = LibGL.get_attrib_location(@gl_program, "vPosition")
    LibGL.enable_vertex_attrib_array(v_position)
    LibGL.vertex_attrib_pointer(v_position, 3, LibGL::VertexAttribPointerType::Float, LibGL::Boolean::False, sizeof(Vertex), Pointer(Void).new(offsetof(Vertex, @x)))

    v_normal = LibGL.get_attrib_location(@gl_program, "vNormal")
    LibGL.enable_vertex_attrib_array(v_normal)
    LibGL.vertex_attrib_pointer(v_normal, 3, LibGL::VertexAttribPointerType::Float, LibGL::Boolean::False, sizeof(Vertex), Pointer(Void).new(offsetof(Vertex, @nx)))

    LibGL.draw_arrays(LibGL::PrimitiveType::Triangles, 0, @stl.size)

    EGL::Lib.swap_buffers(display, surface)
  end
end

AndroidNDK::NativeAppGlue.run(MyApp.new)
