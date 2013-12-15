require 'test_helper'

class MyKlass
  SubKlass = Class.new
end

class AggregateTest < Minitest::Test
  def setup
    @aggregate = ActiveShepherd::Aggregate.new Project.new
  end

  def test_in_namespace_returns_true_only_if_associated_klass_in_namespace
    @aggregate = ActiveShepherd::Aggregate.new MyKlass.new

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

  def test_traversable_associations_excludes_classes_outside_namespace
    refute_includes @aggregate.traversable_associations.keys, :watchers
  end

  def test_traversable_associations_ignores_redundant_associations
    refute_includes @aggregate.traversable_associations.keys, :recent_todo_list
  end

  def test_traversable_associations_returns_traversable_associations
    assert_includes @aggregate.traversable_associations.keys, :detail
    assert_includes @aggregate.traversable_associations.keys, :todo_lists
  end

  def test_traversable_associations_ignores_base_class
    @aggregate = ActiveShepherd::Aggregate.new Project::Comment.new
    refute_includes @aggregate.traversable_associations.keys, :commentable
  end

  def test_traversable_associations_ignores_has_many_through
    refute_includes @aggregate.traversable_associations.keys, :todos
  end
end
