require 'test_helper'

class MyKlass
  SubKlass = Class.new
end

class AggregateTest < MiniTest::Unit::TestCase
  def setup
    @aggregate = ActiveShepherd::Aggregate.new MyKlass.new
  end

  def test_in_namespace_returns_true_only_if_associated_klass_in_namespace
    refute @aggregate.in_namespace?('MyKlass')
    assert @aggregate.in_namespace?('MyKlass::SubKlass')
    refute @aggregate.in_namespace?('MyKlass::SubKlass::SubSubKlass')
    assert @aggregate.in_namespace?('MyKlass::Foo')
    refute @aggregate.in_namespace?('Foo')

    @aggregate = ActiveShepherd::Aggregate.new MyKlass::SubKlass.new
    refute @aggregate.in_namespace?('MyKlass')
    refute @aggregate.in_namespace?('MyKlass::SubKlass')
    assert @aggregate.in_namespace?('MyKlass::SubKlass::SubSubKlass')
    assert @aggregate.in_namespace?('MyKlass::Foo')
    assert @aggregate.in_namespace?('MyKlass::SubSubKlass')
    refute @aggregate.in_namespace?('Foo')
  end
end
