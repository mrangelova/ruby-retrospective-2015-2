require 'digest/sha1'

class ObjectStore
  class Stage
    attr_reader :added_objects, :removed_objects

    def initialize
      @added_objects = {}
      @removed_objects = []
    end

    def add(object_name, object)
      added_objects[object_name] = object
    end

    def remove(object_name)
      removed_objects << object_name
    end

    def empty?
      added_objects.empty? and removed_objects.empty?
    end

    def size
      added_objects.size + removed_objects.size
    end
  end

  class BranchManager
    attr_accessor :current_branch, :branches

    def initialize
      @current_branch = Branch.new('master')
      @branches = [@current_branch]
    end

    def create(name)
      if branch_exists?(name)
        Failure.new("Branch #{name} already exists.")
      else
        branches << Branch.new(name, current_branch.commits.dup)

        Success.new("Created branch #{name}.")
      end
    end

    def remove(branch_name)
      if branch_exists?(branch_name) and current_branch?(branch_name)
        Failure.new('Cannot remove current branch.')
      elsif branch_exists?(branch_name) and not current_branch?(branch_name)
        branches.delete_if { |branch| branch.name == branch_name }

        Success.new("Removed branch #{branch_name}.")
      elsif not branch_exists?(branch_name)
        Failure.new("Branch #{branch_name} does not exist.")
      end
    end

    def checkout(branch_name)
      if branch_exists?(branch_name)
        @current_branch = branches.find { |branch| branch.name == branch_name }

        Success.new("Switched to branch #{branch_name}.")
      else
        Failure.new("Branch #{branch_name} does not exist.")
      end
    end

    def list
      message = branches.map(&:name).sort.map do |branch_name|
        current_branch?(branch_name) ? "* #{branch_name}" : "  #{branch_name}"
      end.join("\n")

      Success.new(message)
    end

    def branch_exists?(branch_name)
      branches.any? { |branch| branch.name == branch_name}
    end

    def current_branch?(branch_name)
      current_branch.name == branch_name
    end

    class Branch
      attr_reader :name
      attr_accessor :commits

      def initialize(name, commits = [])
        @name = name
        @commits = commits
      end

      def commit(commit)
        @commits << commit
      end
    end
  end

  class Commit
    attr_reader :message, :parent, :stage, :date, :hash

    def initialize(message, parent, stage)
      @message = message
      @parent = parent
      @stage = stage
      @date = Time.now
      @hash = Digest::SHA1.hexdigest "#{formatted_date}#{message}"
    end

    def objects
      merged_stage.values
    end

    def object(object_name)
      merged_stage[object_name]
    end

    def has_object?(object_name)
      merged_stage.include?(object_name)
    end

    def to_s
      "Commit #{hash}\nDate: #{formatted_date}\n\n\t#{message}"
    end

    protected

    def merged_stage
      return stage.added_objects unless parent

      parent.merged_stage.merge(stage.added_objects).reject do |name, object|
        stage.removed_objects.include?(name)
      end
    end

    private

    def formatted_date
      @date.strftime("%a %b %d %H:%M %Y %z")
    end
  end

  class Status
    attr_reader :message, :result

    def initialize(message, result = nil)
      @message = message
      @result = result
    end
  end

  class Success < Status
    def success?
      true
    end

    def error?
      false
    end
  end

  class Failure < Status
    def success?
      false
    end

    def error?
      true
    end
  end

  attr_reader :stage, :branch_manager

  def self.init(&block)
    repository = new

    repository.instance_eval &block if block_given?

    repository
  end

  def initialize
    @stage = Stage.new
    @branch_manager = BranchManager.new
  end

  def add(object_name, object)

    stage.add(object_name, object)
    Success.new("Added #{object_name} to stage.", object)
  end

  def remove(object_name)
    if last_commit.has_object? object_name
      stage.remove(object_name)

      Success.new("Added #{object_name} for removal.",
                  last_commit.object(object_name))
    else
      Failure.new("Object #{object_name} is not committed.")
    end
  end

  def commit(message)
    if stage.empty?
      Failure.new("Nothing to commit, working directory clean.")
    else
      current_stage = stage.dup
      current_branch.commit(Commit.new(message, last_commit, current_stage))
      @stage = Stage.new

      Success.new("#{message}\n\t#{current_stage.size} objects changed",
                  last_commit)
    end
  end

  def head
    if last_commit
      Success.new("#{last_commit.message}", last_commit)
    else
      Failure.new("Branch #{current_branch.name} does " \
                  "not have any commits yet.")
    end
  end

  def log
    if current_branch.commits.empty?
      Failure.new("Branch #{current_branch.name} does " \
                  "not have any commits yet.")
    else
      message = current_branch.commits.reverse.map(&:to_s)
      Success.new(message.join("\n\n"))
    end
  end

  def checkout(sha1)
    if current_branch.commits.none? { |commit| commit.hash == sha1 }
      Failure.new("Commit #{sha1} does not exist.")
    else
      commit_index = current_branch.commits.find_index do |commit|
        commit.hash == sha1
      end

      current_branch.commits = current_branch.commits[0..commit_index]

      @stage = last_commit.objects

      Success.new("HEAD is now at #{sha1}.", last_commit)
    end
  end

  def get(object_name)
    if last_commit and last_commit.has_object? object_name
      Success.new("Found object #{object_name}.",
                  last_commit.object(object_name))
    else
      Failure.new("Object #{object_name} is not committed.")
    end
  end

  def branch
    branch_manager
  end

  private

  def last_commit
    current_branch.commits.last
  end

  def current_branch
    branch_manager.current_branch
  end
end