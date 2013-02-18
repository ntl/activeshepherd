require 'test_helper'

class AggregateTest < MiniTest::Unit::TestCase
  def setup
    @project   = Project.new
    @aggregate = Aggro::Aggregate.new(@project)

    @changes = {
      name: ["Clean House", "Clean My House"],
      todo_lists: {
        0 => {
          todos: {
            0 => { text: ["Take out the trash", "Take out my trash"] },
            2 => { text: [nil, "Another task!"] },
          },
        },
      },
    }
  end

  def test_state_setter_sets_attributes
    @aggregate.state = { name: "Foo" }

    assert_equal "Foo", @project.name
  end

  def test_state_getter_gets_attributes
    @project.name = "Foo"

    assert_equal "Foo", @aggregate.state[:name]
  end

  def test_state_setter_sets_attributes_on_has_one_associated_object
    @aggregate.state = { detail: { description: "Foobar" }}

    assert_equal "Foobar", @project.detail.try(:description)
  end

  def test_state_getter_gets_attributes_on_has_one_associated_object
    @project.build_detail({ description: "Foobar" })

    assert_equal "Foobar", @aggregate.state.fetch(:detail, {})[:description]
  end

  def test_state_setter_sets_attributes_on_has_many_associated_object
    @aggregate.state = { todo_lists: [{ todos: [{ text: "Hi" },{ text: "Bye" }] }] }

    assert_equal 1, @project.todo_lists.size
    assert_equal 2, @project.todo_lists.first.todos.size
    assert_equal ["Hi", "Bye"], @project.todo_lists.first.todos.map(&:text)
  end

  def test_state_getter_rejects_id
    refute @aggregate.state.keys.include?(:id)
    refute @aggregate.state.keys.include?("id")
  end

  def test_state_getter_rejects_unpopulated_associations
    assert_equal 0, @project.todo_lists.size
    assert_nil @project.detail

    refute @aggregate.state.has_key?(:todo_lists)
    refute @aggregate.state.has_key?(:detail)
  end

  def test_does_not_walk_associations_to_other_entities
    @aggregate.state = { owner: { name: "Joe Schmoe" } }

    refute_equal "Joe Schmoe", @project.owner.try(:name)
  end

  def test_state_getter_does_not_walk_read_only_associations
    @project.todo_lists.build.tap do |todo_list|
      todo_list.todos.build({ text: "Hi" })
      @project.recent_todo_list = todo_list
    end

    assert_nil @aggregate.state[:recent_todo_list]
    assert_nil @aggregate.state['recent_todo_list']
  end

  def test_state_setter_does_not_walk_read_only_associations
    @aggregate.state = { recent_todo_list: {} }

    assert_nil @project.recent_todo_list
  end

  def test_changes_getter_ignores_foreign_key_relationship_to_parent_object
    build_persisted_state

    @project.todo_lists.build

    assert_equal nil, @aggregate.changes
  end

  def test_all_changes_to_associated_objects_show_up_in_aggregate_changes
    build_persisted_state

    @project.name = "Clean My House"
    @project.todo_lists.first.todos.first.text = "Take out my trash"
    @project.todo_lists.first.todos.build({ text: "Another task!" })

    assert_equal @changes, @aggregate.changes
  end

  def test_applying_changes_shows_up_in_model_and_its_associations
    build_persisted_state
  end

  def test_state_setter_populates_object_graph
    state = {
      name:     "Clean House",
      owner_id: 1,
      todo_lists: [{
        todos: [{
          text: "Take out the trash",
          todo_assignments: [{
            assignee_id: 2,
          },{ 
            assignee_id: 3,
          }],
          comments: [{
            author_id: 1,
            text: "Have this done by Monday",
          },{
            author_id: 2,
            text: "I'll do my best",
          }],
        }],
      }],
    }

    @aggregate.state = state
    #assert_equal state, @aggregate.state
  end

private

  # Test 'changes' behavior with this common background
  def build_persisted_state
    @project.name     = "Clean House"
    @project.owner_id = 1
    @project.todo_lists.build({
      todos_attributes: {
        "0" => { text: "Take out the trash" },
        "1" => { text: "Make your bed" },
      },
    })

    @project.save

    assert_equal({}, @aggregate.changes)
  end
end
