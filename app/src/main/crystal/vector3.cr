struct Vector3(T)
  def initialize(@values : T[3])
  end

  def to_unsafe
    @values.to_unsafe
  end

  def self.new(x : T, y : T, z : T)
    new(T.static_array(x, y, z))
  end

  def self.zero : self
    new(StaticArray(T, 3).new { T.zero })
  end

  def self.additive_identity : self
    zero
  end

  def []?(index : Int) : T?
    unsafe_fetch(index) if 0 <= index < 3
  end

  def [](index : Int) : T
    self[index]? || raise IndexError.new
  end

  {% for v1, i1 in %w(x y z) %}
    def {{ v1.id }} : T
      @values.unsafe_fetch({{ i1 }})
    end

    {% for v2, i2 in %w(x y z) %}
      # :nodoc:
      def {{ v1.id }}{{ v2.id }} : {T, T}
        {@values.unsafe_fetch({{ i1 }}), @values.unsafe_fetch({{ i2 }})}
      end

      {% for v3, i3 in %w(x y z) %}
        # :nodoc:
        def {{ v1.id }}{{ v2.id }}{{ v3.id }} : {T, T, T}
          {@values.unsafe_fetch({{ i1 }}), @values.unsafe_fetch({{ i2 }}), @values.unsafe_fetch({{ i3 }})}
        end
      {% end %}
    {% end %}
  {% end %}

  def to_tuple : Tuple
    xyz
  end

  def inspect(io : IO) : Nil
    io << '<' << x << ", " << y << ", " << z << '>'
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end

  def +(other : Vector3) : Vector3
    Vector3.new(@values.map_with_index { |v, i| v + other.@values.unsafe_fetch(i) })
  end

  def -(other : Vector3) : Vector3
    Vector3.new(@values.map_with_index { |v, i| v - other.@values.unsafe_fetch(i) })
  end

  def + : Vector3(T)
    self
  end

  def - : Vector3(T)
    Vector3.new(@values.map &.-)
  end

  def *(other : Number) : Vector3
    Vector3.new(@values.map &.*(other))
  end

  def /(other : Number) : Vector3
    Vector3.new(@values.map &./(other))
  end

  def dot(other : Vector3) : Number
    x * other.x + y * other.y + z * other.z
  end

  def *(other : Vector3) : Vector3
    Vector3.new(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    )
  end

  def normalize : Vector3(T)
    norm = Math.sqrt(x * x + y * y + z * z)
    Vector3.new(x / norm, y / norm, z / norm)
  end
end

struct Number
  def *(other : Vector3) : Vector3
    Vector3.new(other.@values.map { |v| self * v })
  end

  def /(other : Vector3) : Vector3
    Vector3.new(other.@values.map { |v| self / v })
  end
end

alias Vector3F32 = Vector3(Float32)
