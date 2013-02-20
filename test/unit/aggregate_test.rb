require 'test_helper'

class AggregateTest < MiniTest::Unit::TestCase
  def setup
    Project.destroy_all

    @project   = Project.new
    @aggregate = Aggro::Aggregate.new(@project)

    @state = {
      name:     "Clean House",
      owner_id: 1,
      detail: {
        description: "I need to clean the house"
      },
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
        },{
          text: "Sweep the floor"
        }],
      }],
    }

    @changes = {
      name: ["Clean House", "Clean My House"],
      detail: {
        description: ["I need to clean the house", "I need to clean my house"],
      },
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

  def test_state_getter_ignores_default_scope_attributes
    @project.todo_lists.build({
      todos_attributes: {
        "0" => {
          text: "Foo"
        }
      }
    })

    todo = @project.todo_lists.first.todos.first
    c = todo.comments.build({ text: "Bar" })

    # FIXME
    comment_state = @aggregate.state[:todo_lists].first[:todos].first[:comments].first
    # /fixme
    assert_nil comment_state[:commentable_type]
  end

  def test_state_getter_ignores_has_many_through_associations
  end

  def test_state_setter_ignores_has_many_through_associations
  end

  def test_state_setter_sets_attributes_on_has_many_associated_object
    @aggregate.state = { todo_lists: [{ todos: [{ text: "Hi" },{ text: "Bye" }] }] }

    assert_equal 1, @project.todo_lists.size
    assert_equal 2, @project.todo_lists.first.todos.size
    assert_equal ["Hi", "Bye"], @project.todo_lists.first.todos.map(&:text)
  end

  def test_state_getter_rejects_id
    refute @aggregate.state.keys.include?(:id)
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
  end

  def test_state_getter_ignores_foreign_key_relationship_to_parent_object
    @project.save
    @project.build_detail({ description: "Foo" })

    assert_equal({ description: "Foo" }, @aggregate.state[:detail])
  end

  def test_state_setter_does_not_walk_read_only_associations
    @aggregate.state = { recent_todo_list: {} }

    assert_nil @project.recent_todo_list
  end

  def test_changes_getter_ignores_foreign_key_relationship_to_parent_object
    build_persisted_state

    @project.todo_lists.build

    assert_equal({}, @aggregate.changes)
  end

  def test_all_changes_to_associated_objects_show_up_in_aggregate_changes
    build_persisted_state

    @project.name = "Clean My House"
    @project.detail.description = "I need to clean my house"
    @project.todo_lists.first.todos.first.text = "Take out my trash"
    @project.todo_lists.first.todos.build({ text: "Another task!" })

    assert_equal @changes, @aggregate.changes
  end

  def test_applying_changes_shows_up_in_model_and_its_associations
    @aggregate.state = @state
    @project.save!

    assert_equal "Clean House", @project.name
    assert_equal "I need to clean the house", @project.detail.description
    assert_equal "Take out the trash", @project.todo_lists.first.todos.first.text
    assert_equal 2, @project.todo_lists.first.todos.size
    
    @aggregate.changes = @changes

    assert_equal "Clean My House", @project.name
    assert_equal "I need to clean my house", @project.detail.description
    assert_equal "Take out my trash", @project.todo_lists.first.todos.first.text
    assert_equal 3, @project.todo_lists.first.todos.size
  end

  def test_state_getter_symbolizes_all_keys
    @project.name = "Foo"

    assert_equal({ name: "Foo" }, @aggregate.state)
  end

  def test_state_setter_populates_object_graph
    @aggregate.state = @state
    assert_equal @state, @aggregate.state
  end

  def test_state_setter_marks_existing_associations_for_deletion
    @aggregate.state = @state
    @project.save

    assert_equal 2, @project.todo_lists.first.todos.size

    new_state = Marshal.load(Marshal.dump(@state))

    new_state[:todo_lists].first[:todos].first.tap do |todo|
      todo[:todo_assignments].pop
      todo[:comments].pop
      todo[:comments].unshift({author_id: 2, text: "Brand new comment"})
    end

    @aggregate.state = new_state
    @project.save

    @project.todo_lists.first.todos.first.tap do |todo|
      assert_equal 1, todo.todo_assignments.size
      assert_equal 2, todo.comments.size
      assert_equal ["Brand new comment", "Have this done by Monday"], todo.comments.map(&:text)
    end
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
    @project.build_detail({ description: "I need to clean the house" })

    @project.save

    assert_equal({}, @aggregate.changes)
  end
end
