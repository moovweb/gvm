require 'tmpdir'
require 'fileutils'

def root_path
  File.expand_path('../.', __FILE__)
end

def commit
  @commit ||= (
    ENV['TRAVIS_COMMIT'] || `git rev-parse --abbrev-ref HEAD`.chomp
  )
end

# copy build logs to source directory
def copy_logs(build_directory, label="")
  _build_directory = build_directory
  if _build_directory.nil? || _build_directory.empty?
    raise ArgumentError, "invalid build_directory specified: nil or empty"
  end

  _label = ""
  _label = "(#{label})" unless (label.nil? || label.empty?)

  FileUtils.mkdir("#{root_path}/build_logs") unless Dir.exist?("#{root_path}/build_logs")
  _build_logs = Dir.glob("#{_build_directory}/gvm/logs/*.log")

  # debugging
  printf "Log files #{_label}... (build_directory: #{_build_directory})\n"
  _build_logs.each { |f| printf("%s\n", f) }

  FileUtils.cp(_build_logs, "#{root_path}/build_logs")
end

desc "Run simple tests"
task :default do
  Dir.mktmpdir('gvm-test') do |tmpdir|
    begin
      system(<<-EOSH) || raise(SystemCallError, "system shell (bash) call failed")
        bash -c '
          #{root_path}/binscripts/gvm-installer #{commit} #{tmpdir}
        '
      EOSH
      Dir.glob("#{tmpdir}/gvm/tests/*_comment_test.sh").each do |f|
        system(<<-EOSH) || raise(SystemCallError, "system shell (bash) call failed")
          bash -c '
            source #{tmpdir}/gvm/scripts/gvm
            builtin cd #{tmpdir}/gvm/tests
            tf --text "#{f}"
          '
        EOSH
      end
    rescue SystemCallError => e
      raise e
    ensure
      copy_logs(tmpdir, "task: default")
    end
  end
end

desc "Run scenario tests"
task :scenario do
  Dir["#{root_path}/tests/scenario/*_comment_test.sh"].each do |test|
    name = File.basename(test)
    puts "Running scenario #{name}..."
    Dir.mktmpdir('gvm-test') do |tmpdir|
      begin
        system(<<-EOSH) || raise(SystemCallError, "system shell (bash) call failed")
          bash -c '
            #{root_path}/binscripts/gvm-installer #{commit} #{tmpdir}
            source #{tmpdir}/gvm/scripts/gvm
            builtin cd #{tmpdir}/gvm/tests/scenario
            tf --text "#{name}"
          '
        EOSH
      rescue SystemCallError => e
        raise e
      ensure
        copy_logs(tmpdir, "task: scenario")
      end
    end
  end
end
