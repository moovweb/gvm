require 'tmpdir'

task :default do
  STDOUT.sync = true
  $stdout.sync = true
  root_path = File.expand_path "../.", __FILE__

  Dir.mktmpdir("gvm-test") do |tmpdir|
    puts `binscripts/gvm-installer binary_default #{tmpdir}`
    pid = fork do
      exec("bash -c 'source #{tmpdir}/gvm/scripts/gvm; tf --text #{tmpdir}/gvm/tests/*'")
    end
    Process.waitpid(pid)
  end
end
