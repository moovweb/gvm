require 'tmpdir'

def root_path
  File.expand_path('../.', __FILE__)
end

def commit
  @commit ||= (
    ENV['TRAVIS_COMMIT'] || `git rev-parse --abbrev-ref HEAD`.chomp
  )
end

task :default do
  Dir.mktmpdir('gvm-test') do |tmpdir|
    system(<<-EOSH) || fail
      bash -c '
        #{root_path}/binscripts/gvm-installer #{commit} #{tmpdir}
        source #{tmpdir}/gvm/scripts/gvm
        builtin cd #{tmpdir}/gvm/tests
        tf --text *_comment_test.sh
      '
    EOSH
  end
end

task :scenario do
  Dir["#{root_path}/tests/scenario/*_comment_test.sh"].each do |test|
    name = File.basename(test)
    puts "Running scenario #{name}..."
    Dir.mktmpdir('gvm-test') do |tmpdir|
      system(<<-EOSH) || fail
        bash -c '
          #{root_path}/binscripts/gvm-installer #{commit} #{tmpdir}
          source #{tmpdir}/gvm/scripts/gvm
          builtin cd #{tmpdir}/gvm/tests/scenario
          tf --text #{name}
        '
      EOSH
    end
  end
end
