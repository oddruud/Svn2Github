require 'active_record'

class SvnRepo < ActiveRecord::Base
   has_many :svn_external_entries
   has_one :github_project
   belongs_to :repo_migration
   
   def repo_name
     return self.url
   end
   
   #removed the trunk bit from an url
   def self.base_url svn_url
     return nil if svn_url.nil?
     filtered = svn_url.dup
     filtered.gsub!("/trunk", "")
     filtered.gsub!("/tags", "")
     filtered.gsub!("/branches", "")
     return filtered
   end
   
   def trunk_url
     return "#{self.url}/trunk"
   end
   
   def base_name
     return self.url.split("/").last
   end
   
   
end


