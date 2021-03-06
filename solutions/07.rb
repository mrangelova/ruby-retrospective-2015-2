module LazyMode
  class Date
    include Comparable

    attr_reader :year, :month, :day

    def initialize(date)
      @year, @month, @day = date.split('-').map(&:to_i)
    end

    def <=>(other)
      number_of_days_since_beginning_of_time <=>
        other.number_of_days_since_beginning_of_time
    end

    def +(number_of_days)
      day_number = number_of_days_since_beginning_of_time + number_of_days

      new_year = day_number / 360 + 1
      new_month = (day_number % 360) / 30 + 1
      new_month -= 1 if (day_number % 360) % 30 == 0
      new_day = (day_number % 30).zero? ? 30 : day_number % 30

      Date.new("%04d-%02d-%02d" % [new_year, new_month, new_day])
    end

    def to_s
      "%04d-%02d-%02d" % [year, month, day]
    end

    def number_of_days_since_beginning_of_time
      (year - 1) * 360 + (month - 1) * 30 + day
    end
  end

  class Note
    DEFAULT_STATUS = :topostpone
    DEFAULT_BODY = ''

    attr_reader :header, :file_name, :tags
    attr_accessor :body, :status, :schedule

    def self.create(header, file_name, tags, &block)
      note = new(header, file_name, tags)

      DSL.new(note).instance_eval(&block)

      note
    end

    def initialize(header, file_name, tags)
      @header = header
      @file_name = file_name
      @tags = tags
      @status = DEFAULT_STATUS
      @body = DEFAULT_BODY
      @sub_notes = []
    end

    def add_sub_note(sub_note)
      @sub_notes << sub_note
    end

    def nested_notes
      @sub_notes + @sub_notes.map(&:nested_notes).flatten
    end

    def scheduled_for?(date)
      schedule.happening_on_date? date
    end

    private

    class DSL
      def initialize(note)
        @note = note
      end

      private

      def note(header, *tags, &block)
        sub_note = Note.create(header, @note.file_name, tags, &block)
        @note.add_sub_note(sub_note)
      end

      def status(status)
        @note.status = status
      end

      def body(body)
        @note.body = body
      end

      def scheduled(date)
        occurrence_interval = /\+[0-9]+[mwd]/.match(date)

        if occurrence_interval
          @note.schedule = RecurringEvent.new(date, occurrence_interval[0])
        else
          @note.schedule = DiscreteEvent.new(date)
        end
      end
    end
  end

  class DiscreteEvent
    def initialize(date)
      @date = Date.new(date)
    end

    def happening_on_date?(date)
      @date == date
    end
  end

  class RecurringEvent
    NUMBER_OF_DAYS = {'m' => 30, 'w' =>  7, 'd' => 1}

    def initialize(first_occurrence, occurrence_interval)
      @first_occurrence = Date.new(first_occurrence)
      @days_between_occurrences = parse(occurrence_interval)
    end

    def happening_on_date?(date)
      enum_for(:each_occurrence).lazy.
        take_while { |event_date| event_date <= date }.include? date
    end

    private

    def parse(occurrence_interval)
      cycle = /[mwd]/.match(occurrence_interval)[0]
      number_of_cycles = /[0-9]+/.match(occurrence_interval)[0].to_i

      NUMBER_OF_DAYS[cycle] * number_of_cycles
    end

    def each_occurrence
      yield @first_occurrence
      next_occurrence = @first_occurrence + @days_between_occurrences

      loop do
        yield next_occurrence
        next_occurrence += @days_between_occurrences
      end
    end
  end

  class File
    class Agenda
      class Note < Struct.new(:header, :file_name, :body,
                              :status, :tags, :date)
      end

      attr_accessor :notes

      def initialize(notes)
        @notes = notes
      end

      def where(status: nil, tag: nil, text: nil)
        filtered_notes = notes_filtered_by_tag(tag) &
          notes_filtered_by_status(status) & notes_filtered_by_text(text)

        Agenda.new(filtered_notes)
      end

      private

      def notes_filtered_by_tag(tag)
        return notes if not tag

        notes.select { |note| note.tags.include? tag }
      end

      def notes_filtered_by_status(status)
        return notes if not status

        notes.select { |note| note.status == status }
      end

      def notes_filtered_by_text(text)
        return notes if not text

        notes.select do |note|
          text.match(note.header) or text.match(note.body)
        end
      end
    end

    attr_reader :name, :notes

    def initialize(name, &block)
      @name = name
      @notes = []

      instance_eval &block
    end

    def daily_agenda(date)
      daily_notes = @notes.select { |note| note.scheduled_for? date }

      daily_notes.map! do |note|
        Agenda::Note.new(note.header, note.file_name, note.body,
                         note.status, note.tags, date)
      end

      Agenda.new(daily_notes)
    end

    def weekly_agenda(date)
      week_notes = (0..6).map do |number_of_days|
        daily_agenda(date + number_of_days).notes
      end.flatten

      Agenda.new(week_notes)
    end

    private

    def note(header, *tags, &block)
      note = Note.create(header, name, tags, &block)

      @notes += [note, * note.nested_notes]
    end
  end

  def self.create_file(file_name, &block)
    File.new(file_name, &block)
  end
end