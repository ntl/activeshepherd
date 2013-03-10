require 'active_record'
require 'active_support/core_ext/string'
require 'hashie'
require 'pp'
require 'pry'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_shepherd'

require 'minitest/mock'
require 'minitest/reporters'

require 'minitest/autorun'

MiniTest::Reporters.use! MiniTest::Reporters::DefaultReporter.new

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveShepherd.enable!(ActiveRecord::Base)

require 'setup_test_models'
