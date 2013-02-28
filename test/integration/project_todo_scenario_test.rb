require 'test_helper'

class IntegrationTest < MiniTest::Unit::TestCase
  def setup
    Project.destroy_all

    @project = Project.new

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
            2 => { text: [nil, "Another task!"], _create: '1' },
          },
        },
      },
    }
  end

  def test_state_setter_sets_attributes
    @project.aggregate_state = { name: "Foo" }

    assert_equal "Foo", @project.name
  end

  def test_state_getter_gets_attributes
    @project.name = "Foo"

    assert_equal "Foo", @project.aggregate_state[:name]
  end

  def test_state_setter_sets_attributes_on_has_one_associated_object
    @project.aggregate_state = { detail: { description: "Foobar" }}

    assert_equal "Foobar", @project.detail.try(:description)
  end

  def test_state_getter_gets_attributes_on_has_one_associated_object
    @project.build_detail({ description: "Foobar" })

    assert_equal "Foobar", @project.aggregate_state.fetch(:detail, {})[:description]
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
    comment_state = @project.aggregate_state[:todo_lists].first[:todos].first[:comments].first
    # /fixme
    assert_nil comment_state[:commentable_type]
  end

  def test_state_getter_ignores_has_many_through_associations
  end

  def test_state_setter_ignores_has_many_through_associations
  end

  def test_state_setter_sets_attributes_on_has_many_associated_object
    @project.aggregate_state = { todo_lists: [{ todos: [{ text: "Hi" },{ text: "Bye" }] }] }

    assert_equal 1, @project.todo_lists.size
    assert_equal 2, @project.todo_lists.first.todos.size
    assert_equal ["Hi", "Bye"], @project.todo_lists.first.todos.map(&:text)
  end

  def test_state_getter_rejects_id
    refute @project.aggregate_state.keys.include?(:id)
  end

  def test_state_getter_rejects_unpopulated_associations
    assert_equal 0, @project.todo_lists.size
    assert_nil @project.detail

    refute @project.aggregate_state.has_key?(:todo_lists)
    refute @project.aggregate_state.has_key?(:detail)
  end

  def test_does_not_walk_associations_to_other_entities
    @project.aggregate_state = { owner: { name: "Joe Schmoe" } }

    refute_equal "Joe Schmoe", @project.owner.try(:name)
  end

=begin
  # FIXME: rails 4 is removing read only associations
  def test_state_getter_does_not_walk_read_only_associations
    @project.todo_lists.build.tap do |todo_list|
      todo_list.todos.build({ text: "Hi" })
      @project.recent_todo_list = todo_list
    end

    assert_nil @project.aggregate_state[:recent_todo_list]
  end

  def test_state_setter_does_not_walk_read_only_associations
    @project.aggregate_state = { recent_todo_list: {} }

    assert_nil @project.recent_todo_list
  end
=end

  def test_state_getter_ignores_foreign_key_relationship_to_parent_object
    @project.save
    @project.build_detail({ description: "Foo" })

    assert_equal({ description: "Foo" }, @project.aggregate_state[:detail])
  end

  def test_changes_getter_ignores_foreign_key_relationship_to_parent_object
    build_persisted_state

    @project.todo_lists.build

    assert_equal({todo_lists: { 1 => {_create: '1' }}}, @project.aggregate_changes)
  end

  def test_all_changes_to_associated_objects_show_up_in_aggregate_changes
    build_persisted_state

    @project.name = "Clean My House"
    @project.detail.description = "I need to clean my house"
    @project.todo_lists.first.todos.first.text = "Take out my trash"
    @project.todo_lists.first.todos.build({ text: "Another task!" })

    assert_equal @changes, @project.aggregate_changes
  end

  def test_applying_changes_shows_up_in_model_and_its_associations
    build_persisted_state

    @project.aggregate_state = @state
    @project.save!

    assert_equal "Clean House", @project.name
    assert_equal "I need to clean the house", @project.detail.description
    assert_equal "Take out the trash", @project.todo_lists.first.todos.first.text
    assert_equal 2, @project.todo_lists.first.todos.size
    
    @project.aggregate_changes = @changes

    assert_equal "Clean My House", @project.name
    assert_equal "I need to clean my house", @project.detail.description
    assert_equal "Take out my trash", @project.todo_lists.first.todos.first.text
    assert_equal 3, @project.todo_lists.first.todos.size
  end

  def test_applying_reverse_changes_invokes_apply_change_on_the_reverse_hash
    build_persisted_state

    @project.aggregate_changes = @changes
    @project.save!

    assert_equal "Clean My House", @project.name
    assert_equal "I need to clean my house", @project.detail.description
    assert_equal "Take out my trash", @project.todo_lists.first.todos.first.text
    assert_equal 3, @project.todo_lists.first.todos.size

    @project.reverse_aggregate_changes = @changes
    @project.save!

    assert_equal "Clean House", @project.name
    assert_equal "I need to clean the house", @project.detail.description
    assert_equal "Take out the trash", @project.todo_lists.first.todos.first.text
    assert_equal 2, @project.todo_lists.first.todos.size
  end

  def test_state_getter_symbolizes_all_keys
    @project.name = "Foo"

    assert_equal({ name: "Foo" }, @project.aggregate_state)
  end

  def test_state_setter_populates_object_graph
    @project.aggregate_state = @state
    assert_equal @state, @project.aggregate_state
  end

  def test_state_setter_marks_existing_associations_for_deletion
    @project.aggregate_state = @state
    @project.save

    assert_equal 2, @project.todo_lists.first.todos.size

    new_state = Marshal.load(Marshal.dump(@state))

    new_state[:todo_lists].first[:todos].first.tap do |todo|
      todo[:todo_assignments].pop
      todo[:comments].pop
      todo[:comments].unshift({author_id: 2, text: "Brand new comment"})
    end
    new_state.delete(:detail)

    @project.aggregate_state = new_state
    @project.save
    @project.reload

    @project.todo_lists.first.todos.first.tap do |todo|
      assert_equal 1, todo.todo_assignments.size
      assert_equal 2, todo.comments.size
      assert_equal ["Brand new comment", "Have this done by Monday"], todo.comments.map(&:text)
    end

    assert_nil @project.detail
  end

  def test_state_setter_resets_unsupplied_attributes_to_default
    @project.aggregate_state = @state.merge(status: 5)
    @project.save

    new_state = Marshal.load(Marshal.dump(@state))
    new_state.delete(:status)

    @project.aggregate_state = new_state

    assert_equal Project.new.status, @project.status
  end

  def state_setter_can_set_timestamps
    timestamp = (1.year.ago - 15.seconds)

    @project.state = { created_at: timestamp, updated_at: timestamp + 14.days }
    assert_equal timestamp, @project.created_at
    assert_equal timestamp + 14.days, @project.updated_at
  end

  def test_state_getter_respects_serialized_attributes
    @project.fruit = :apple
    assert_equal 'ELPPA', @project.aggregate_state[:fruit]
  end

  def test_state_setter_respects_serialized_attributes
    @project.aggregate_state = @state
    assert_equal nil, @project.fruit

    @state[:fruit] = 'EGNARO'
    @project.aggregate_state = @state
    assert_equal :orange, @project.fruit
  end

  def test_state_changes_getter_and_setter_respect_serialized_attributes
    build_persisted_state

    @project.fruit = :banana
    assert_equal [nil, 'ANANAB'], @project.aggregate_changes[:fruit]
    @project.save!
    assert_equal :banana, @project.reload.fruit

    @project.fruit = :pear
    assert_equal ['ANANAB', 'RAEP'], @project.aggregate_changes[:fruit]

    @project.reload
    assert_equal :banana, @project.fruit
    @project.aggregate_changes = { fruit: [ 'ANANAB', 'OGNAM'] }
    assert_equal :mango, @project.fruit
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

    assert_equal({}, @project.aggregate_changes)
  end

  def reverse_changes
    @changes = {
      name: ["Clean My House", "Clean House"],
      detail: {
        description: ["I need to clean my house", "I need to clean the house"],
      },
      todo_lists: {
        0 => {
          todos: {
            0 => { text: ["Take out my trash", "Take out the trash"] },
            2 => { _destroy: '1' },
          },
        },
      },
    }
  end
end
