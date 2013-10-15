Gem::Specification.new do |s|
  s.name        = 'svn2github'
  s.version     = '0.1.0'
  s.date        = '2013-09-11'
  s.summary     = "Creates github projects from svn repositories"
  s.description = "Creates a git repository from an SVN repository with svn history intact. Creates a github project and pushes the git repo to this project. Creates git submodules from svn externals."
  s.authors     = ["Ruud op den Kelder"]
  s.email       = 'ruudodk@gmail.com'
  s.executables = ['svn2github']
  s.files       = Dir['lib/**/*.rb']
  s.files       += Dir['bin/*']
  s.files       += Dir['data/**/*']
  s.homepage    = 'https://github.com/oddruud/Svn2Github'
end