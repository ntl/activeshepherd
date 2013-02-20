require 'test_helper'

class IntegrationTest < MiniTest::Unit::TestCase
  def setup
    @owner      = User.create!(name: "Jane Owner")
    @assignee_1 = User.create!(name: "Joe Peasant")
    @assignee_2 = User.create!(name: "Jack Peon")

    @project = Project.new

    @my_project_state = {
      name:     "Clean House",
      owner_id: @owner.id,
      todo_lists: [{
        todos: [{
          text: "Take out the trash",
          todo_assignments: [{
            assignee_id: @assignee_1.id,
          },{ 
            assignee_id: @assignee_2.id,
          }],
          comments: [{
            author_id: @owner.id,
            text: "Have this done by Monday",
          },{
            author_id: @assignee_1.id,
            text: "I'll do my best",
          }],
        }],
      }],
    }
  end

  def teardown
    @owner.destroy
  end

  def test_can_get_and_set_aggregate_state
    @project.aggregate_state = @my_project_state
    assert_equal @my_project_state, @project.aggregate_state
  end
end
