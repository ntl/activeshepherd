require "bundler/gem_tasks"

require "rake/testtask"

desc "Update ctags"
task :ctags do
  `ctags -R lib test`
end

desc "Jump into a console with the test environment loaded"
task :console do
  $:.push File.expand_path("../test", __FILE__)
  require "test_helper"
  require "irb"

  binding.pry
end

Rake::TestTask.new do |t|
  t.pattern = "test/**/*_test.rb"
  t.libs << "test"
end

task default: "test"
