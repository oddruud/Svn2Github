require 'rubygems'
require 'optparse'
require 'json'
require 'utilities'
require 'migration_data'
require 'repo_migration'

module RepoMigrate
include Utilities

def start
  options = {}
  options[:config_url] =  "#{root_path}/data/repo_migration_config.json"
  
  svn_repo_url = ARGV[0] 
  
  unless valid_svn_repo_url(svn_repo_url) 
    puts red("please provide a valid svn repo url")
    exit 
  end
  
  #load in repo migration credentials
  RepoMigration.load_configuration options 
  RepoMigration.set_local_repo_workspace("#{root_path}/data/git_workspace")
  
  #Setup the database:
  MigrationData.start("#{root_path}/data/database.yml")
  MigrationData.define_schema()
  
  repo_migration = RepoMigration.get(svn_repo_url)
  if repo_migration.migrated.nil?
    repo_migration.migrate 
  else
    puts "#{svn_repo_url} has already been migrated"
  end
end

def valid_svn_repo_url(svn_repo_url)
  return false if svn_repo_url.nil?
  return false if svn_repo_url == ""
  output = `svn ls #{svn_repo_url}` ; result = $?.success?
  return result  
end

end


