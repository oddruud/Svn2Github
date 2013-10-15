require 'octokit'
require 'json'
require 'utilities'
require 'active_record'
require 'svn_repo'
require 'github_project'
require 'svn_external_entry'
require 'date'

class Pair
  attr_accessor :one, :two
  def initialize(one, two)
    @one = one
    @two = two
  end
end

class RepoMigration < ActiveRecord::Base
  has_one :svn_repo
  
  @@configuration = nil 
  @@github_client = nil
  @@github_user = nil
  @@svn_user = nil  
  @@repos_dir = nil  
    
  def self.set_local_repo_workspace(workspace)  
    @@repos_dir = workspace
    unless File.directory?(@@repos_dir)
      FileUtils.mkdir_p @@repos_dir
    end
  end
    
  def self.get(svn)
    svn_repo = SvnRepo.where(:url => svn )
    repo_migration = RepoMigration.where(:svn_repo_id => svn_repo[0].id) unless svn_repo.empty?
       
    if repo_migration.nil? || repo_migration.empty?
      repo_migration = RepoMigration.create_rm(svn) 
    end
    
    return repo_migration 
  end 
  
  def self.create_rm(svn_url)
    svn_url = SvnRepo.base_url svn_url
       
    new_repo = SvnRepo.new(:name => svn_url, :url => svn_url, :migrated => false ) 
    new_repo.save()      
                             
    repo_migration = RepoMigration.new(:svn_repo_id => new_repo.id, :type => "RepoMigration", :created => Date.today, :last_updated => Date.today ) 
    repo_migration.save()        
    
    #now assign a RepoMigration ID to the svn repo 
    new_repo.repo_migration_id = repo_migration.id
    new_repo.save()
    
    puts yellow("Created migration for #{svn_url}")     
                 
    return repo_migration    
  end
  
  def migrate
      unless self.migrated.nil?
        puts red("SVN repo #{svn_repo.url} has already been migrated.")
        print "Do you want to remigrate this project? (y/n)"
        answer = STDIN.gets()  
        if answer.match(/y/).nil?
          puts "Cancelled migration of #{svn_repo.url}"
          return
        end
      end
    
      puts "Migrating #{svn_repo.url}"
      
      #phase 1: gather all the externals in the svn repo:
      #update the known externals list:
      @svn_externals = gather_externals
      update_svn_externals(@svn_externals)
    
      #phase 2: create a github project
      init_github_project unless github_project_exists?
      
      #phase 3: git svn clone the svn dir
      svn_to_git
      
      #phase 4: add submodules to git project
      add_submodules
      
      #phase 5: push the git repository to github
      push_to_github
      
      #phase 6:
      self.migrated = Date.today  
      svn_repo().migrated = true
  
      svn_repo().save(); 
      self.save(); 
  end
    
  
  def update_svn_externals(svn_externals)
    external_repo_migrations = Array.new 
      
    svn_externals.each_pair do |directory, external_list|
      external_list.each do |external_pair|
        external_entries = SvnExternalEntry.where(:svn_repo_id => svn_repo_id, :root_directory => directory)
        puts yellow("* EXTERNAL: #{external_pair[:svn]}, name: #{external_pair[:id]} @ #{directory}")
        if external_entries.empty?
          svn_external = SvnRepo.find_by(:url => external_pair[:svn])
          
          if svn_external.nil? #create a migration for this external svn repo. 
            svn_external_migration = RepoMigration.get(external_pair[:svn]) 
            svn_external = SvnRepo.find_by(:url => external_pair[:svn])
            #puts "NEW external migration: #{svn_external_migration.svn_repo.url}, id: #{svn_external_migration.svn_repo_id}"
          else
            svn_external_migration = RepoMigration.where(:svn_repo_id => svn_external.id)  #svn_externalid
            #puts "external migration already exists: #{svn_external_migration.svn_repo.url}, id: #{svn_external_migration.svn_repo_id}"
          end
          
          unless svn_external.migrated
            #puts "adding migration to array: #{svn_external_migration.svn_repo.url}"
            external_repo_migrations << svn_external_migration 
          end
          
          svn_external_entry = SvnExternalEntry.new(:svn_repo_id => svn_repo_id, :svn_external_id => svn_external.id, :root_directory => directory, :name => external_pair[:id])  
          svn_external_entry.save
        end      
      end
    end
    
    migrate_external_repo_migrations(external_repo_migrations)
  end

  def migrate_external_repo_migrations(repo_migration_array)
    return if repo_migration_array.size == 0 
   
    print "Migrate some or all of #{repo_migration_array.size} external(s) (y/n)?"
    answer = STDIN.gets() 
   
    unless answer.match(/y/).nil?
      repo_migration_array.each do |migration|
        
        if repo_migration_array.size > 1
          puts "Do you want to migrate external #{migration.svn_repo.url} ? (y/n)"
          answer = STDIN.gets()  
        else
          answer = "yes"
        end
        
        unless answer.match(/y/).nil?
          migration.migrate
        end
      end
    end
  end


def init_github_project
  puts yellow("Creating github project for #{svn_repo.url}....")
  
  #create entry
  the_github_project = GithubProject.new(:complete_migration => false)  
  the_github_project.description = "This is a test" #"this project is migrated from #{svn_repo.url}"
     
  suggested_github_project_name = svn_repo.base_name
  
  print "Do you want to name the github project: '#{suggested_github_project_name}' (yes/no):"
  name_with_suggested_name = STDIN.gets()  

  success = false 
  while success == false do    
    if name_with_suggested_name.match(/y/).nil?
       puts "How do you want to name the project on github?"
       the_github_project.name = STDIN.gets().gsub("\n","")
     else
       the_github_project.name = suggested_github_project_name
    end

    log_info "creating github project: #{the_github_project.name}"  
  
    options = Hash.new
    options[:description] =    the_github_project.description 
    options[:has_wiki] =       @@configuration["github"]["has_wiki"]
    options[:has_issues] =     @@configuration["github"]["has_issues"]
    options[:has_downloads] =  @@configuration["github"]["has_downloads"] 
  
    begin 
      result = @@github_client.create_repository the_github_project.name, options
      success = true
    rescue Octokit::UnprocessableEntity => repo_exists_already 
      success = false 
      puts red("the github repo with name #{the_github_project.name} already exists")
      name_with_suggested_name = "no"
    end 
  end
  
  puts green("git project created at: #{result["clone_url"]}")
  
  the_github_project.url = result["clone_url"]
  the_github_project.save()
  
  self.github_project_id = the_github_project.id 
  self.save()
end  
  
def svn_to_git
  puts yellow("Performing SVN2GIT on #{svn_repo.url}") 
  puts yellow("creating GIT repo at #{local_git_repo_dir}")
 
  execute("mkdir #{local_git_repo_dir}") 
  execute("cd #{local_git_repo_dir} && svn2git #{svn_repo.url} --username #{@@svn_user}")
end

def push_to_github
  puts green("pushing project to github.")
  toDirectory =  "cd #{local_git_repo_dir}" 
  execute("#{toDirectory} && git remote add origin #{github_project.url}")
  execute("#{toDirectory} && git push -u origin master")
end
  
def add_submodules  
    externals  = SvnExternalEntry.where(:svn_repo_id => svn_repo.id)
    submodules = ""
    
    externals.each do |external_entry|
        puts  yellow("adding submodule #{external_entry.name}")
         
        external_migration = RepoMigration.find_by(:svn_repo_id => external_entry.svn_external_id)
        github_submodule =   GithubProject.find(external_migration.github_project_id)
      
        full_path = external_entry.root_directory
        relative_path = full_path[/trunk\/.*/][6..full_path.size]
          
        external_path = "#{local_git_repo_dir}/#{relative_path}"
        
        begin 
          puts "creating external dir #{external_path}"
          FileUtils.mkdir_p external_path
        rescue 
          puts "could not create #{external_path}"
        end
        
        execute("cd #{local_git_repo_dir} && git submodule add #{github_submodule.url} #{relative_path}/#{external_entry.name}")   
        submodules = "#{submodules}, #{external_entry.name}"
      end
      
  unless submodules == ""
       execute("cd #{local_git_repo_dir} && git add *")  
       execute("cd #{local_git_repo_dir} && git commit -m \"added submodules: #{submodules}\"")
  end
end
    
def gather_externals
  
  FileUtils.mkdir_p "../data/temp"
  execute("touch ../data/temp/externals")
  execute("svn propget svn:externals #{svn_repo.url} -R > ../data/temp/externals")
  text = IO.read("../data/temp/externals")
  token_list = text.gsub(/\s+/m, ' ').strip.split(" ")
  
  directory = ""
  external_name = ""
  svn_externals = Hash.new
    
  token_list.each_index do |i| 
    token = token_list[i]
    next_token = (i+1 < token_list.length)  ? token_list[i+1] : ""
    
    token_type = :none 
    
    if token.match(/svn:\/\//).nil? == false and next_token == "-"  
      token_type = :directory 
    elsif token.match(/svn:\/\/|http:\/\/svn/).nil? == false
      token_type = :external_svn_location
    elsif token.match(/^-/).nil?
      token_type = :external_name
    end
    
    case token_type
      when :directory
        directory = token
        svn_externals[directory] = Array.new if svn_externals[directory].nil?       
      when :external_name
        external_name = token 
      when :external_svn_location   
        external_svn_location = token 
        svn_externals[directory] << {:id => external_name, :svn => SvnRepo.base_url(external_svn_location)} 
    end
  end
  
  return svn_externals
end

  def self.load_configuration(options)
    @@configuration = JSON.parse(IO.read(options[:config_url]))
    @@configuration["github"]["has_wiki"] =  options[:has_wiki] unless options[:has_wiki].nil?
    @@configuration["github"]["has_issues"] =  options[:has_issues] unless options[:has_issues].nil?
    @@configuration["github"]["has_downloads"] =   options[:has_downloads] unless options[:has_downloads].nil?
    @@repos_dir =  @@configuration["local_git_directory"]
  
    begin 
      @@github_client = Octokit::Client.new(:login => @@configuration["github"]["user"], :password => @@configuration["github"]["password"])  
      puts " logged into github as #{@@configuration["github"]["user"]}"
    rescue 
       puts red("something went wrong during authenticating to github")
    end
    @@github_user = @@configuration["github"]["user"]   
    @@svn_user = @@configuration["svn"]["user"]   
  end

  def self.show_github_info
   user_info = Octokit.user @@configuration["github"]["user"]
   puts yellow("USER---------------------------------------")
   puts yellow(JSON.pretty_generate(user_info))
  end
  
  def self.show_github_repos
     repos =  @@github_client.all_repositories
     puts yellow(JSON.pretty_generate(repos))
  end

  def svn_repo
    begin 
      return SvnRepo.find svn_repo_id
    rescue ActiveRecord::RecordNotFound => record_not_found 
      return nil
    end
  end
  
  def github_project
    return nil if github_project_id.nil?
    begin 
      return GithubProject.find github_project_id
    rescue ActiveRecord::RecordNotFound => record_not_found 
      return nil
    end
  end
  
  def github_project_exists?
    return !github_project.nil?
  end
  
  def local_git_repo_dir 
    return "#{@@repos_dir}/#{github_project.name}"
  end  

end 