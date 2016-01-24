require 'digest/sha1'

class ObjectStore
  def self.init(&block)
    repo = new
    repo.instance_eval &block if block_given?
    repo
  end

  def initialize
    @stage = {}
    @branch_manager = BranchManager.new
  end

  def add(name, object)
    @stage[name] = object
    Status.new(message: "Added #{name} to stage.",
               success: true,
               result: object)
  end

  def remove(name)
    if @stage.include? name
      Status.new(message: "Added #{name} for removal.",
                 success: true,
                 result: @stage.delete(name))
    else
      Status.new(message: "Object #{name} is not committed.",
                 success: false)
    end
  end

  def commit(message)
    if number_of_objects_changed == 0
      Status.new(message: "Nothing to commit, working directory clean.",
                 success: false)
    else
      objects_changed = number_of_objects_changed
      current_branch.commits << Commit.new(message, @stage.dup)
      Status.new(message: "#{message}\n\t#{objects_changed} objects changed",
                 success: true,
                 result: last_commit)
    end
  end

  def number_of_objects_changed
    return @stage.size unless last_commit

    objects_added = (@stage.values - last_commit.objects).size
    objects_removed = (last_commit.objects - @stage.values).size

    objects_added + objects_removed
  end

  def last_commit
    current_branch.commits.last
  end

  def head
    if last_commit
      Status.new(message: "#{last_commit.message}",
                 success: true,
                 result: last_commit)
    else
      Status.new(message: "Branch #{branch.current_branch.name} " \
                          "does not have any commits yet.",
                 success: false)
    end
  end

  def log
    if current_branch.commits.empty?
      Status.new(message: "Branch #{branch.current_branch.name} " \
                          "does not have any commits yet.",
                 success: false)
    else
      message = current_branch.commits.reverse.map do |commit|
        "Commit #{commit.hash}\n" \
        "Date: #{commit.date.strftime("%a %b %d %H:%M %Y %z")}" \
        "\n\n\t#{commit.message}"
      end
      Status.new(message: message.join("\n\n"),
                 success: true)
    end
  end

  def checkout(sha1)
    if current_branch.commits.none? { |commit| commit.hash == sha1 }
      Status.new(message: "Commit #{sha1} does not exist.",
                 success: false)
    else
      commit_index =
        current_branch.commits.find_index { |commit| commit.hash == sha1 }
      current_branch.commits = current_branch.commits[0..commit_index]
      @stage = last_commit.objects_with_names

      Status.new(message: "HEAD is now at #{sha1}.",
                 success: true,
                 result: last_commit)
    end
  end

  def branch
    @branch_manager
  end

  def current_branch
    branch.current_branch
  end

  def get(name)
    if last_commit and last_commit.objects_with_names.include?(name)
      Status.new(message: "Found object #{name}.",
                 success: true,
                 result: last_commit.objects_with_names[name])
    else
      Status.new(message: "Object #{name} is not committed.",
                 success: false)
    end
  end

  class BranchManager
    attr_accessor :current_branch, :branches

    def initialize
      @current_branch = Branch.new(name: 'master')
      @branches = [@current_branch]
    end

    def create(name)
      if branch_exists?(name)
        Status.new(message: "Branch #{name} already exists.",
                   success: false)
      else
        branches << Branch.new(name: name, commits: current_branch.commits)
        Status.new(message: "Created branch #{name}.",
                   success: true)
      end
    end

    def remove(name)
      if branch_exists?(name) and current_branch?(name)
        Status.new(message: 'Cannot remove current branch.',
                   success: false)
      elsif branch_exists?(name) and not current_branch?(name)
        branches.delete_if { |branch| branch.name == name }
        Status.new(message: "Removed branch #{name}.",
                   success: true)
      elsif not branch_exists?(name)
        Status.new(message: "Branch #{name} does not exist.",
                   success: false)
      end
    end

    def checkout(name)
      if branch_exists?(name)
        current_branch = branches.find { |branch| branch.name == name }
        unless current_branch.commits.empty?
          @stage = current_branch.commits.last.objects_with_names
        end
        Status.new(message: "Switched to branch #{name}.",
                   success: true)
      else
        Status.new(message: "Branch #{name} does not exist.",
                   success: false)
      end
    end

    def list
      message = branches.map(&:name).sort.map do |name|
        current_branch?(name) ? "* #{name}" : "  #{name}"
      end
      Status.new(message: message.join("\n"),
                 success: true)
    end

    def branch_exists?(name)
      branches.any? { |branch| branch.name == name}
    end

    def current_branch?(name)
      current_branch.name == name
    end

    class Branch
      attr_reader :name
      attr_accessor :commits

      def initialize(name:, commits: [])
        @name = name
        @commits = commits
      end
    end
  end

  class Status
    attr_reader :message, :success, :result

    def initialize(message:, success: , result: nil)
      @message = message
      @success = success
      @result = result
    end

    def success?
      success
    end

    def error?
      not success?
    end
  end

  class Commit
    attr_reader :message, :objects, :objects_with_names, :date, :hash

    def initialize(message, objects)
      @message = message
      @objects = objects.values
      @objects_with_names = objects
      @date = Time.now
      @hash = Digest::SHA1.hexdigest "#{@time}#{message}"
    end
  end
end