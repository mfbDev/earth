# This file is autogenerated. Instead of editing this file, please use the
# migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.

ActiveRecord::Schema.define(:version => 11) do

  create_table "directory_info", :force => true do |t|
    t.column "path", :string, :default => "", :null => false
    t.column "server_id", :integer, :default => 0, :null => false
  end

  create_table "file_info", :force => true do |t|
    t.column "name", :text
    t.column "modified", :datetime
    t.column "size", :integer, :limit => 15
    t.column "uid", :integer
    t.column "gid", :integer
    t.column "directory_info_id", :integer
  end

  create_table "servers", :force => true do |t|
    t.column "name", :string, :default => "", :null => false
    t.column "watch_directory", :string, :default => "", :null => false
  end

end