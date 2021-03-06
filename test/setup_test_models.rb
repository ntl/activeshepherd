ActiveRecord::Migration.create_table :users, force: true do |t|
  t.string :name
  t.belongs_to :favorite_project
end

ActiveRecord::Migration.create_table :comments, force: true do |t|
  t.string :text
  t.string :type
  t.belongs_to :commentable, polymorphic: true
  t.belongs_to :author
end

ActiveRecord::Migration.create_table :projects, force: true do |t|
  t.string :name
  t.belongs_to :owner
  t.integer :status, default: 1, null: false
  t.string :fruit
  t.timestamps
end

ActiveRecord::Migration.create_table :project_details, force: true do |t|
  t.belongs_to :project
  t.text :description
end

ActiveRecord::Migration.create_table :project_todo_lists, force: true do |t|
  t.belongs_to :project
  t.timestamps
end

ActiveRecord::Migration.create_table :project_todos, force: true do |t|
  t.string :text
  t.integer :comments_count, default: 0, null: false
  t.belongs_to :todo_list
end

ActiveRecord::Migration.create_table :project_todo_assignments, force: true do |t|
  t.belongs_to :todo
  t.belongs_to :assignee
end


class User < ActiveRecord::Base
  act_as_aggregate_root!

  has_many :projects, inverse_of: :owner, dependent: :destroy, autosave: true,
    validate: true, foreign_key: :owner_id
  belongs_to :favorite_project, class_name: "Project"
end

class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true, counter_cache: true
  belongs_to :author, class_name: "User"
end

class Project < ActiveRecord::Base
  act_as_aggregate_root!

  belongs_to :owner, class_name: "User", inverse_of: :projects, touch: true
  has_many :watchers, inverse_of: :favorite_project, class_name: "User",
    foreign_key: :favorite_project_id

  has_one :detail, inverse_of: :project, dependent: :destroy, autosave: true

  has_many :todo_lists, validate: true, dependent: :destroy, inverse_of: :project, autosave: true
  has_many :todos, through: :todo_lists # not part of aggregate

  has_one :recent_todo_list, ->{ order("updated_at DESC") },
    class_name: "Project::TodoList"

  FruitSerializer = Class.new do
    def self.dump(fruit)
      return nil if fruit.nil?
      fruit.to_s.reverse.upcase
    end

    def self.load(blob)
      return nil if blob.nil?
      blob.reverse.downcase.to_sym
    end
  end
  serialize :fruit, FruitSerializer
end

class Project::Detail < ActiveRecord::Base
  belongs_to :project, inverse_of: :detail
end

class Project::TodoList < ActiveRecord::Base
  belongs_to :project, inverse_of: :todo_lists
  has_many :todos, validate: true, dependent: :destroy, inverse_of: :todo_list

  accepts_nested_attributes_for :todos
end

class Project::Todo < ActiveRecord::Base
  belongs_to :todo_list, inverse_of: :todos
  has_many :todo_assignments, inverse_of: :todo, dependent: :destroy, autosave: true

  has_many :assignees, through: :todo_assignments
  has_many :comments, inverse_of: :todo, foreign_key: "commentable_id"

  validates :text, uniqueness: { scope: :todo_list_id }
end

class Project::TodoAssignment < ActiveRecord::Base
  belongs_to :todo, inverse_of: :todo_assignments
  belongs_to :assignee, class_name: "User"
end

class Project::Comment < Comment
  belongs_to :todo, foreign_key: "commentable_id", inverse_of: :comments

  default_scope { where({ commentable_type: "Project::Todo" }) }
end


# Instantiate an instance of each model class; this causes mistakes in the above
# code to fail fast.
models = ObjectSpace.each_object(Class).select do |klass|
  klass < ActiveRecord::Base
end

models.each(&:new)
