class Spreadsheet
  class Error < RuntimeError
  end

  class CellIndex
    CELL_LABEL_PATTERN = /\A([A-Z]+)([0-9]+)\z/.freeze
    ALPHABET_SIZE      = 'Z'.ord - 'A'.ord + 1
    ALPHABET_OFFSET    = 'A'.ord - 1

    attr_reader :row, :column

    def initialize(cell_label)
      @row, @column = parse(cell_label)
    end

    private

    def parse(cell_label)
      if cell_label =~ CELL_LABEL_PATTERN
        column_index = column_label_to_number($1) - 1
        row_index = $2.to_i - 1
      else
        raise Error.new("Invalid cell index '#{cell_index}'")
      end

      [row_index, column_index]
    end

    private

    def column_label_to_number(column_label)
      column_label.chars.reduce(0) do |sum, letter|
        sum * ALPHABET_SIZE + letter.ord - ALPHABET_OFFSET
      end
    end
  end

  class Number
    PATTERN = /\A([\d\.]+)\z/

    attr_reader :number

    def self.matches?(expression)
      expression =~ PATTERN
    end

    def initialize(expression)
      if expression.is_a?(String)
        @number = PATTERN.match(expression).captures.first.to_f
      else
        @number = expression
      end
    end

    def evaluate(sheet)
      number
    end

    def to_s
      if number == number.to_i
        number.to_i.to_s
      else
        '%.2f' % number
      end
    end
  end

  class Functions
    FORMULAS = {
      ADD:       ->(x, y, *more) { [x, y, more].flatten.reduce(:+) },
      MULTIPLY:  ->(x, y, *more) { [x, y, more].flatten.reduce(:*) },
      SUBTRACT: ->(minuend, subtrahend) { minuend - subtrahend },
      DIVIDE:    ->(dividend, divisor) { dividend / divisor },
      MOD:       ->(dividend, divisor) { dividend % divisor },
    }

    class << self
      def call(function, *arguments)
        formula = FORMULAS[function.to_sym]

        raise Error.new("Unknown function '#{function}'") unless formula

        check_arguments_count(function, *arguments)

        formula.call(*arguments)
      end

      private

      def check_arguments_count(function, *arguments)
        formula = FORMULAS[function.to_sym]

        if formula.arity > 0
          check_exact_number_of_arguments(function, formula, arguments)
        elsif formula.arity < -1
          check_enough_arguments(function, formula, arguments)
        end
      end

      def check_enough_arguments(function, formula, arguments)
        if formula.arity.abs - 1 > arguments.size
          raise Error.new "Wrong number of arguments for '#{function}': " \
            "expected at least #{formula.arity.abs - 1}, got #{arguments.size}"
        end
      end

      def check_exact_number_of_arguments(function, formula, arguments)
        if formula.arity != arguments.size
          raise Error.new "Wrong number of arguments for '#{function}': " \
            "expected #{formula.arity}, got #{arguments.size}"
        end
      end
    end
  end

  class Function
    PATTERN = /\A([A-Z]+)\((.*)\)\z/

    attr_reader :function, :arguments

    def self.matches?(expression)
      expression =~ PATTERN
    end

    def initialize(expression)
      function, arguments = PATTERN.match(expression).captures

      @function  = function
      @arguments = arguments.split(',').map(&:strip)
    end

    def evaluate(sheet)
      Number.new(Functions.call(function, * evaluated_arguments(sheet)))
    end

    private

    def evaluated_arguments(sheet)
      arguments.map { |argument| Expression.new(argument).evaluate(sheet) }
    end
  end

  class CellReference
    attr_reader :reference

    def self.matches?(expression)
      expression =~ CellIndex::CELL_LABEL_PATTERN
    end

    def initialize(expression)
      @reference = expression
    end

    def evaluate(sheet)
      Expression.new(sheet[reference]).evaluate(sheet)
    end
  end


  class Expression
    ALL_EXPRESSION_TYPES = [
      Number,
      CellReference,
      Function,
    ]

    attr_reader :expression

    def initialize(expression)
      @expression = expression
    end

    def evaluate(sheet)
      expression_type = ALL_EXPRESSION_TYPES.find do |type|
        type.matches?(expression)
      end

      if expression_type
        expression_type.new(expression).evaluate(sheet)
      else
        raise Error.new("Invalid expression '#{expression}'")
      end
    end
  end


  ROW_DELIMITER    = "\n"
  COLUMN_DELIMITER = / {2,}|\t/

  attr_reader :cells

  def initialize(sheet = '')
    @cells = build_table(sheet)
  end

  def empty?
    cells.empty?
  end

  def cell_at(cell_label)
    cell_index = CellIndex.new(cell_label)

    cell = cells[cell_index.row][cell_index.column] if cells[cell_index.row]

    if cell
      cell
    else
      raise Error.new("Cell '#{cell_label}' does not exist")
    end
  end

  def [](cell_label)
    evaluate(cell_at(cell_label))
  end

  def to_s
    cells.map do |row|
      row.map { |cell| evaluate(cell) }.join("\t")
    end.join("\n")
  end

  private

  def build_table(sheet)
    sheet.strip.split(ROW_DELIMITER).map do |row|
      row.strip.split(COLUMN_DELIMITER)
    end
  end

  def evaluate(cell_content)
    if cell_content.start_with?('=')
      Expression.new(cell_content.delete('=')).evaluate(self).to_s
    else
      cell_content
    end
  end
end