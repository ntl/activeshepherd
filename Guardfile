# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'minitest' do
  # with Minitest::Unit
  watch(%r|^test/(.*)\/?(.*)_test\.rb|)
  watch(%r{^lib/aggro/(.*/)?([^/]+)\.rb$})  { |m| "test/unit/#{m[1]}#{m[2]}_test.rb" }
  watch(%r{^lib/aggro.rb})            { "test" }
  watch(%r|^test/test_helper\.rb|)    { "test" }
end
