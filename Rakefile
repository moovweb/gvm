require 'tmpdir'

task :default do
  root_path = File.expand_path "../.", __FILE__
  Dir.mktmpdir("gvm-test") do |tmpdir|
    puts `binscripts/gvm-installer binary_default #{tmpdir}`
    pid = fork do
      exec("bash -c 'source #{tmpdir}/gvm/scripts/gvm; tf --text #{tmpdir}/gvm/tests/*'")
    end
    Process.waitpid(pid)
  end
end

task :scenario do
  root_path = File.expand_path "../.", __FILE__
  Dir["#{root_path}/tests/scenario/*_comment_test.sh"].each do |test|
    name = File.basename(test)
    puts "Running scenario #{name}..."
    Dir.mktmpdir("gvm-test") do |tmpdir|
      install = `binscripts/gvm-installer binary_default #{tmpdir}`
      pid = fork do
        exec("bash -c 'source #{tmpdir}/gvm/scripts/gvm; tf --text #{tmpdir}/gvm/tests/scenario/#{name}'")
      end
      Process.waitpid(pid)
    end
  end
end
