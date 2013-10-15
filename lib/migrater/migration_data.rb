require 'utilities'
require 'sqlite3'
require 'active_record'
require 'yaml'
require 'logger'

module MigrationData
  
  class Column
    attr_accessor :name
    attr_accessor :type
    attr_accessor :options
    
    def initialize(name, type, options = {})
      @name = name
      @type = type 
      @options = options
    end
    
  end
  
  def MigrationData.start db_config_filename 
    dbconfig = YAML::load(File.open(db_config_filename))
    ActiveRecord::Base.establish_connection(dbconfig)
    ActiveRecord::Base.logger = Logger.new(File.open('../logs/database.log', 'a'))
    #puts "database connected: #{ActiveRecord::Base.connected?()}"   
  end
  
  def MigrationData.define_schema(force_clear = false)
    
    if force_clear
       puts red("Are you sure you want to clear the repo migration database?")
       answer = gets
       unless answer.match('y').nil?
         puts "clearing the database.." 
         ActiveRecord::Base.connection.tables.each do |table_name|
           ActiveRecord::Base.connection.drop_table table_name
         end
       end
    end
    
     if  ActiveRecord::Base.connection.table_exists? "svn_repos"
       return
     end
     
    #svn repos:
    svn_repos_columns = Array.new
    svn_repos_columns << Column.new(:name, :string)
    svn_repos_columns << Column.new(:url, :string)
    svn_repos_columns << Column.new(:repo_migration_id, :integer)
    svn_repos_columns << Column.new(:migrated, :boolean, {:default => false})
    MigrationData.update_create_table("svn_repos", svn_repos_columns)
       
    #external svn entries
    svn_external_entries_columns = Array.new
    svn_external_entries_columns << Column.new(:svn_repo_id, :integer)
    svn_external_entries_columns << Column.new(:svn_external_id, :integer)
    svn_external_entries_columns << Column.new(:name, :string)
    svn_external_entries_columns << Column.new(:root_directory, :string)
    MigrationData.update_create_table("svn_external_entries", svn_external_entries_columns)
    
    #git submodule entries
    git_submodule_entries_columns = Array.new
    git_submodule_entries_columns << Column.new(:github_project_id, :integer)
    git_submodule_entries_columns << Column.new(:github_submodule_id, :integer)
    git_submodule_entries_columns << Column.new(:name, :string)
    git_submodule_entries_columns << Column.new(:root_directory, :string)
    MigrationData.update_create_table("git_submodule_entries", git_submodule_entries_columns)
    
    #github projects
    github_projects_columns = Array.new
    github_projects_columns << Column.new(:name, :string)
    github_projects_columns << Column.new(:url, :string)
    github_projects_columns << Column.new(:description, :string)
    github_projects_columns << Column.new(:complete_migration, :boolean)
    MigrationData.update_create_table("github_projects", github_projects_columns)
   
    #migrations:
    repo_migrations_columns = Array.new
    repo_migrations_columns << Column.new(:svn_repo_id, :integer)
    repo_migrations_columns << Column.new(:github_project_id, :integer)
    repo_migrations_columns << Column.new(:type, :string)
    repo_migrations_columns << Column.new(:created, :datetime)
    repo_migrations_columns << Column.new(:last_updated, :datetime)
    repo_migrations_columns << Column.new(:migrated, :datetime)
    MigrationData.update_create_table("repo_migrations", repo_migrations_columns)
 end
    
  def MigrationData.update_create_table(table_name, columns)
    unless ActiveRecord::Base.connection.table_exists? table_name  
      ActiveRecord::Schema.define do
        create_table table_name do |table|
          columns.each do |column|
            table.column column.name, column.type
          end
        end
      end
    else
      #puts "#{table_name} exists"
      #table already exists.
      # ActiveRecord::Schema.define do
      #   columns.each do |column|
      #     add_column(table_name, column.name, column.type, column.options) unless column_exists?(table_name, column.name)
      #   end
      # end
    end
  end
end 

