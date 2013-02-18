ActiveRecord::Migration.create_table :users do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :comments do |t|
  t.string :text
  t.string :type
  t.belongs_to :commentable, polymorphic: true
  t.belongs_to :author
end

ActiveRecord::Migration.create_table :projects do |t|
  t.string :name
  t.belongs_to :owner
  t.timestamps
end

ActiveRecord::Migration.create_table :project_todo_lists do |t|
  t.belongs_to :project
  t.timestamps
end

ActiveRecord::Migration.create_table :project_todos do |t|
  t.string :text
  t.belongs_to :todo_list
end

ActiveRecord::Migration.create_table :project_todo_assignments do |t|
  t.belongs_to :todo
  t.belongs_to :assignee
end
