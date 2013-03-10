# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'minitest' do
  # with Minitest::Unit
  watch(%r|^test/(.*)\/?(.*)_test\.rb|)
  watch(%r{^lib/active_shepherd/(.*/)?([^/]+)\.rb$})  { |m| "test/unit/#{m[1]}#{m[2]}_test.rb" }
  watch(%r{^lib/active_shepherd.rb})  { "test" }
  watch(%r|^test/test_helper\.rb|)    { "test" }

  watch(%r|^test/integration/project_todo_scenario/(.*)\.rb$|) do 
    "test/integration/project_todo_scenario_test.rb"
  end

  watch(%r{^lib/.*\.rb$})  { |m| "test/integration/project_todo_scenario_test.rb" }
end
