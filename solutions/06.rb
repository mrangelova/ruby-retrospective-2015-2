module TurtleGraphics
  module Canvas
    class ASCII
      def initialize(symbols)
        @symbols = symbols
      end

      def render_grid(grid)
        maximum_steps = grid.max

        grid.map { |cell| symbol_for_step_count(cell, maximum_steps) }
          .each_slice(grid.dimensions.last).map { |row| row.join }.join("\n")
      end

      private

      def symbol_for_step_count(steps, maximum_steps)
        intensity = steps.to_f / maximum_steps
        symbol_index = (intensity * (@symbols.size - 1)).ceil

        @symbols[symbol_index]
      end
    end

    class HTML
      TEMPLATE = <<-TEMPLATE.freeze
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
              width: %{pixel_size}px;
              height: %{pixel_size}px;
              background-color: black;
              padding: 0;
            }
          </style>
        </head>
        <body>
          <table>%{rows}</table>
        </body>
        </html>
      TEMPLATE

      def initialize(pixel_size)
        @pixel_size = pixel_size
      end

      def render_grid(grid)
        maximum_intensity = grid.max

        TEMPLATE % {
          pixel_size: @pixel_size,
          rows: table_rows(grid, maximum_intensity.to_f)
        }
      end

      private

      def table_rows(grid, maximum_intensity)
        columns = grid.map do |cell_value|
          '<td style="opacity: %.2f"></td>' % (cell_value / maximum_intensity)
        end.each_slice(grid.dimensions.last)

        columns.map do |column|
          "<tr>#{column.join('')}</tr>"
        end.join('')
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

  class Position
    def initialize(grid, row, column)
      @grid   = grid
      @row    = row
      @column = column
    end

    def next(direction)
      next_row    = (@row + direction[0]) % @grid.dimensions[0]
      next_column = (@column + direction[1]) % @grid.dimensions[1]

      [next_row, next_column]
    end
  end

  class Turtle
    DIRECTIONS = {up: [-1, 0], right: [0, 1], down: [1, 0], left: [0, -1]}
    INITIAL_POSITION = Grid::ORIGIN
    INITIAL_DIRECTION = :right

    def initialize(number_of_rows, number_of_columns)
      @grid = Grid.new(number_of_rows, number_of_columns)

      spawn_at(*INITIAL_POSITION)
    end

    def draw(canvas = TurtleGraphics::Canvas::Numerical.new(@grid), &block)
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
      next_position = @position.next(DIRECTIONS[@direction])

      step_on_position(*next_position)
    end

    private

    def step_on_position(row, column)
      @position = Position.new(@grid, row, column)
      @grid.increment_cell_value(row, column)
    end
  end
end