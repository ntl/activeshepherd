$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'aggro'

require 'minitest/mock'
require 'minitest/reporters'

require 'minitest/autorun'

MiniTest::Reporters.use! MiniTest::Reporters::DefaultReporter.new
