require 'active_record'

class SvnExternalEntry < ActiveRecord::Base
  has_one :svn_repo
  has_one :svn_external
end