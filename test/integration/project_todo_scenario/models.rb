User = Class.new(ActiveRecord::Base)

class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true, counter_cache: true
  belongs_to :author, class_name: "User"
end

class Project < ActiveRecord::Base
  include Aggro::AggregateRoot

  belongs_to :owner, class_name: "User", readonly: true

  has_many :todo_lists, validate: true, dependent: :destroy, inverse_of: :project
  has_many :todos, through: :todo_lists # not part of aggregate
end

class Project::TodoList < ActiveRecord::Base
  belongs_to :project
  has_many :todos, validate: true, dependent: :destroy, inverse_of: :todo_list
end

class Project::Todo < ActiveRecord::Base
  belongs_to :todo_list, inverse_of: :todo_list
  has_many :todo_assignments, inverse_of: :todo, dependent: :destroy

  has_many :assignees, through: :todo_assignments
  has_many :comments, inverse_of: :todo, foreign_key: "commentable_id"

  validates :text, uniqueness: { scope: :todo_list_id }
end

class Project::TodoAssignment < ActiveRecord::Base
  belongs_to :todo_list, inverse_of: :todo
  belongs_to :assignee, class_name: "User", readonly: true
end

class Project::Comment < Comment
  belongs_to :todo, foreign_key: "commentable_id", inverse_of: :comments

  default_scope where({ commentable_type: "Project::Todo" })
end

models = ObjectSpace.each_object(Class).select do |klass|
  klass < ActiveRecord::Base
end

models.each(&:new)
