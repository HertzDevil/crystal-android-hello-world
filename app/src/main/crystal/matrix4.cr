require "./vector3"

# TODO: this is row-major, convert to column-major
struct Matrix4(T)
  def initialize(@values : T[16])
  end

  def to_unsafe
    @values.to_unsafe
  end

  def self.identity : self
    one = T.new(1)
    zero = T.zero
    new(
      T.static_array(
        one, zero, zero, zero,
        zero, one, zero, zero,
        zero, zero, one, zero,
        zero, zero, zero, one,
      ),
    )
  end

  def self.zero : self
    new(StaticArray(T, 16).new { T.zero })
  end

  def self.multiplicative_identity : self
    identity
  end

  def self.additive_identity : self
    zero
  end

  def self.scale(*, x : T = T.new(1), y : T = T.new(1), z : T = T.new(1)) : self
    zero = T.zero
    new(
      T.static_array(
        x, zero, zero, zero,
        zero, y, zero, zero,
        zero, zero, z, zero,
        zero, zero, zero, T.new(1),
      ),
    )
  end

  def self.scale(vector : Vector3(T)) : self
    scale(x: vector.x, y: vector.y, z: vector.z)
  end

  def self.translate(*, x : T = T.zero, y : T = T.zero, z : T = T.zero) : self
    one = T.new(1)
    zero = T.zero
    new(
      T.static_array(
        one, zero, zero, x,
        zero, one, zero, y,
        zero, zero, one, z,
        zero, zero, zero, one,
      ),
    )
  end

  def self.translate(vector : Vector3(T)) : self
    translate(x: vector.x, y: vector.y, z: vector.z)
  end

  def self.rotate(*, x : Number) : self
    one = T.new(1)
    zero = T.zero
    new(
      T.static_array(
        one, zero, zero, zero,
        zero, Math.cos(x), -Math.sin(x), zero,
        zero, Math.sin(x), Math.cos(x), zero,
        zero, zero, zero, one,
      ),
    )
  end

  def self.rotate(*, y : Number) : self
    one = T.new(1)
    zero = T.zero
    new(
      T.static_array(
        Math.cos(y), zero, Math.sin(y), zero,
        zero, one, zero, zero,
        -Math.sin(y), zero, Math.cos(y), zero,
        zero, zero, zero, one,
      ),
    )
  end

  def self.rotate(*, z : Number) : self
    one = T.new(1)
    zero = T.zero
    new(
      T.static_array(
        Math.cos(z), -Math.sin(z), zero, zero,
        Math.sin(z), Math.cos(z), zero, zero,
        zero, zero, one, zero,
        zero, zero, zero, one,
      ),
    )
  end

  # def self.look_at(eye : Vector3(T) | Vector4(T), center : Vector3(T) | Vector4(T), up : Vector3(T) | Vector4(T)) : self
  def self.look_at(eye : Vector3(T), center : Vector3(T), up : Vector3(T)) : self
    # eye = eye.homogenize.xyz_vector unless eye.is_a?(Vector3)
    # center = center.homogenize.xyz_vector unless center.is_a?(Vector3)
    # up = up.homogenize.xyz_vector unless up.is_a?(Vector3)

    f = (center - eye).normalize
    s = (f * up).normalize
    u = s * f

    zero = T.zero
    new(
      T.static_array(
        s.x, s.y, s.z, zero,
        u.x, u.y, u.z, zero,
        -f.x, -f.y, -f.z, zero,
        zero, zero, zero, T.new(1),
      ),
    ) * translate(-eye)
  end

  def self.frustum(left : T, right : T, bottom : T, top : T, near : T, far : T) : self
    raise ArgumentError.new if left == right
    raise ArgumentError.new if top == bottom
    raise ArgumentError.new if near == far
    raise ArgumentError.new if near <= 0
    raise ArgumentError.new if far <= 0

    r_width = T.new(1) / (right - left)
    r_height = T.new(1) / (top - bottom)
    r_depth = T.new(1) / (near - far)
    x = T.new(2) * (near * r_width)
    y = T.new(2) * (near * r_height)
    a = (right + left) * r_width
    b = (top + bottom) * r_height
    c = (far + near) * r_depth
    d = T.new(2) * (far * near * r_depth)

    zero = T.zero
    new(
      T.static_array(
        x, zero, a, zero,
        zero, y, b, zero,
        zero, zero, c, d,
        zero, zero, -T.new(1), zero,
      ),
    )
  end

  def []?(x : Int, y : Int) : T?
    unsafe_fetch(y * 4 + x) if (0 <= x < 4) && (0 <= y < 4)
  end

  def [](x : Int, y : Int) : T
    self[x, y]? || raise IndexError.new
  end

  def with_entry(x : Int, y : Int, value : T) : Matrix4(T)
    raise IndexError.new unless (0 <= x < 4) && (0 <= y < 4)
    values = @values.dup
    values[y * 4 + x] = value
    Matrix4(T).new(values)
  end

  def inspect(io : IO) : Nil
    io << "<<" << @values.unsafe_fetch(0) << ", " << @values.unsafe_fetch(1) << ", " << @values.unsafe_fetch(2) << ", " << @values.unsafe_fetch(3)
    io << ">, <" << @values.unsafe_fetch(4) << ", " << @values.unsafe_fetch(5) << ", " << @values.unsafe_fetch(6) << ", " << @values.unsafe_fetch(7)
    io << ">, <" << @values.unsafe_fetch(8) << ", " << @values.unsafe_fetch(9) << ", " << @values.unsafe_fetch(10) << ", " << @values.unsafe_fetch(11)
    io << ">, <" << @values.unsafe_fetch(12) << ", " << @values.unsafe_fetch(13) << ", " << @values.unsafe_fetch(14) << ", " << @values.unsafe_fetch(15)
    io << ">>"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end

  def transpose : Matrix4(T)
    Matrix4.new(
      T.static_array(
        @values.unsafe_fetch(0),
        @values.unsafe_fetch(4),
        @values.unsafe_fetch(8),
        @values.unsafe_fetch(12),
        @values.unsafe_fetch(1),
        @values.unsafe_fetch(5),
        @values.unsafe_fetch(9),
        @values.unsafe_fetch(13),
        @values.unsafe_fetch(2),
        @values.unsafe_fetch(6),
        @values.unsafe_fetch(10),
        @values.unsafe_fetch(14),
        @values.unsafe_fetch(3),
        @values.unsafe_fetch(7),
        @values.unsafe_fetch(11),
        @values.unsafe_fetch(15),
      ),
    )
  end

  def +(other : Matrix4) : Matrix4
    Matrix4.new(@values.map_with_index { |v, i| v + other.@values.unsafe_fetch(i) })
  end

  def -(other : Matrix4) : Matrix4
    Matrix4.new(@values.map_with_index { |v, i| v - other.@values.unsafe_fetch(i) })
  end

  def + : Matrix4(T)
    self
  end

  def - : Matrix4(T)
    Matrix4.new(@values.map &.-)
  end

  def *(other : Number) : Matrix4
    Matrix4.new(@values.map &.*(other))
  end

  def /(other : Number) : Matrix4
    Matrix4.new(@values.map &./(other))
  end

  def *(other : Matrix4) : Matrix4
    Matrix4(typeof(@values[0] * other.@values[0])).mul(self, other)
  end

  def self.mul(x : Matrix4, y : Matrix4) : self
    new(
      T.static_array(
        x.@values[0] * y.@values[0] + x.@values[1] * y.@values[4] + x.@values[2] * y.@values[8] + x.@values[3] * y.@values[12],
        x.@values[0] * y.@values[1] + x.@values[1] * y.@values[5] + x.@values[2] * y.@values[9] + x.@values[3] * y.@values[13],
        x.@values[0] * y.@values[2] + x.@values[1] * y.@values[6] + x.@values[2] * y.@values[10] + x.@values[3] * y.@values[14],
        x.@values[0] * y.@values[3] + x.@values[1] * y.@values[7] + x.@values[2] * y.@values[11] + x.@values[3] * y.@values[15],
        x.@values[4] * y.@values[0] + x.@values[5] * y.@values[4] + x.@values[6] * y.@values[8] + x.@values[7] * y.@values[12],
        x.@values[4] * y.@values[1] + x.@values[5] * y.@values[5] + x.@values[6] * y.@values[9] + x.@values[7] * y.@values[13],
        x.@values[4] * y.@values[2] + x.@values[5] * y.@values[6] + x.@values[6] * y.@values[10] + x.@values[7] * y.@values[14],
        x.@values[4] * y.@values[3] + x.@values[5] * y.@values[7] + x.@values[6] * y.@values[11] + x.@values[7] * y.@values[15],
        x.@values[8] * y.@values[0] + x.@values[9] * y.@values[4] + x.@values[10] * y.@values[8] + x.@values[11] * y.@values[12],
        x.@values[8] * y.@values[1] + x.@values[9] * y.@values[5] + x.@values[10] * y.@values[9] + x.@values[11] * y.@values[13],
        x.@values[8] * y.@values[2] + x.@values[9] * y.@values[6] + x.@values[10] * y.@values[10] + x.@values[11] * y.@values[14],
        x.@values[8] * y.@values[3] + x.@values[9] * y.@values[7] + x.@values[10] * y.@values[11] + x.@values[11] * y.@values[15],
        x.@values[12] * y.@values[0] + x.@values[13] * y.@values[4] + x.@values[14] * y.@values[8] + x.@values[15] * y.@values[12],
        x.@values[12] * y.@values[1] + x.@values[13] * y.@values[5] + x.@values[14] * y.@values[9] + x.@values[15] * y.@values[13],
        x.@values[12] * y.@values[2] + x.@values[13] * y.@values[6] + x.@values[14] * y.@values[10] + x.@values[15] * y.@values[14],
        x.@values[12] * y.@values[3] + x.@values[13] * y.@values[7] + x.@values[14] * y.@values[11] + x.@values[15] * y.@values[15],
      ),
    )
  end

  # def *(other : Vector4) : Vector4
  #   Vector4(typeof(@values[0] * other.@values[0])).new(
  #     @values[0] * other.@values[0] + @values[1] * other.@values[1] + @values[2] * other.@values[2] + @values[3] * other.@values[3],
  #     @values[4] * other.@values[0] + @values[5] * other.@values[1] + @values[6] * other.@values[2] + @values[7] * other.@values[3],
  #     @values[8] * other.@values[0] + @values[9] * other.@values[1] + @values[10] * other.@values[2] + @values[11] * other.@values[3],
  #     @values[12] * other.@values[0] + @values[13] * other.@values[1] + @values[14] * other.@values[2] + @values[15] * other.@values[3],
  #   )
  # end
end

struct Number
  def *(other : Matrix4) : Matrix4
    Matrix4.new(other.@values.map { |v| self * v })
  end

  def /(other : Matrix4) : Matrix4
    Matrix4.new(other.@values.map { |v| self / v })
  end
end

alias Matrix4F32 = Matrix4(Float32)
