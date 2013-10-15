require 'active_record'

class GithubProject < ActiveRecord::Base
  belongs_to :svn_repo
  
end