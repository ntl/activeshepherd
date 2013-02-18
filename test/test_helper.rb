$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'aggro'

require 'minitest/mock'
require 'minitest/reporters'

require 'minitest/autorun'

require 'pp'
require 'pry'

MiniTest::Reporters.use! MiniTest::Reporters::DefaultReporter.new

require 'active_record'
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

require 'setup_test_models'
