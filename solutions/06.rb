module TurtleGraphics
  class Canvas
    def pixel_intensities(grid)
      grid_max_value = grid.max

      grid.map { |cell_value| Rational(cell_value, grid_max_value) }
    end

    class ASCII < Canvas
      def initialize(symbols)
        @symbols = symbols
        @intensity_symbols = generate_intensities
      end

      def render_grid(grid)
        pixel_intensities(grid).map { |intensity| to_symbol(intensity) }
          .each_slice(grid.dimensions.last).map { |row| row.join }.join("\n")
      end

      private

      def to_symbol(pixel_intensity)
        @intensity_symbols.select do |intensity|
          intensity === pixel_intensity
        end.values.first
      end

      def generate_intensities
        intensity_symbols = {0 => @symbols[0]}

        (1...@symbols.size).each do |symbol_number|
          intensity_range = Rational(symbol_number - 1, @symbols.size - 1)..
            Rational(symbol_number, @symbols.size - 1)

          intensity_symbols[intensity_range] = @symbols[symbol_number]
        end

        intensity_symbols
      end
    end

    class HTML < Canvas
      def initialize(pixel_size)
        @pixel_size = pixel_size
      end

      def render_grid(grid)
<<-EOS
<!DOCTYPE html>
<html>
<head>
  <title>Turtle graphics</title>

  <style>
    table {
      border-spacing: 0;
    }

    tr {
      padding: 0;
    }

    td {
      width: #{@pixel_size}px;
      height: #{@pixel_size}px;

      background-color: black;
      padding: 0;
    }
  </style>
</head>
<body>
  <table>
#{table(grid)}
  </table>
</body>
</html>
EOS
      end

      private

      def pixel_opacity(intensity)
        format('%.2f', intensity)
      end

      def table(grid)
        pixel_intensities(grid).map { |intensity| "       <td style=" \
          "\"opacity: #{pixel_opacity(intensity)}\"></td>\n" }.to_a
          .each_slice(grid.dimensions.last)
          .map { |row| row.join.insert(0, "    <tr>\n").insert(-1, "    </tr>\n") }
          .join
      end
    end

    class Numerical
      def initialize(grid)
        @grid = grid
      end

      def render_grid(grid)
        grid.cells
      end
    end

  end

  class Grid
    include Enumerable

    ORIGIN = [0, 0]
    INITIAL_VALUE = 0

    attr_reader :dimensions, :cells

    def initialize(number_of_rows, number_of_columns)
      @dimensions = [number_of_rows, number_of_columns]
      @cells = Array.new(number_of_rows) do
        Array.new(number_of_columns) { INITIAL_VALUE }
      end
    end

    def reset_cell_value(row, column)
      @cells[row][column] = INITIAL_VALUE
    end

    def increment_cell_value(row, column)
      @cells[row][column] += 1
    end

    def each(&block)
      @cells.each { |row| row.each { |cell_value| yield cell_value } }
    end

    def max
      @cells.flatten.max
    end
  end

  class Turtle
    DIRECTIONS = {up: [-1, 0], right: [0, 1], down: [1, 0], left: [0, -1]}
    INITIAL_POSITION = Grid::ORIGIN
    INITIAL_DIRECTION = :right

    attr_reader :grid

    def initialize(number_of_rows, number_of_columns)
      @grid = Grid.new(number_of_rows, number_of_columns)
      spawn_at(*INITIAL_POSITION)
    end

    def draw(canvas = TurtleGraphics::Canvas::Numerical.new(grid), &block)
      instance_eval &block
      canvas.render_grid(@grid)
    end

    def turn_left
      @direction = case @direction
                     when :right then :up
                     when :up    then :left
                     when :left  then :down
                     when :down  then :right
                   end
    end

    def turn_right
      @direction = case @direction
                     when :right then :down
                     when :down  then :left
                     when :left  then :up
                     when :up    then :right
                   end
    end

    def spawn_at(row, column)
      @grid.reset_cell_value(*INITIAL_POSITION)
      look(INITIAL_DIRECTION)

      step_on_position(row, column)
    end

    def look(orientation)
      @direction = orientation
    end

    def move
      step_on_position(*next_position)
    end

    private

    def next_position
      row    = (@position[0] + DIRECTIONS[@direction][0]) % @grid.dimensions[0]
      column = (@position[1] + DIRECTIONS[@direction][1]) % @grid.dimensions[1]

      [row, column]
    end

    def step_on_position(row, column)
      @position = [row, column]
      @grid.increment_cell_value(row, column)
    end
  end
end