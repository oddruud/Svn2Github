require "logger"


module Utilities

@@logger = Logger.new(STDOUT)

@@debug_mode = true 

def execute(command)
  log_info(command)
  system(command) 
end

def log_info(msg)
  @@logger.info("#{msg}")
end 

def log_warning(msg)
  @@logger.warn("#{msg}")
end 

def log_error(msg)
  @@logger.error("#{msg}")
end 

def log_fatal(msg)
  @@logger.fatal("#{msg}")
end 

def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def root_path
  spec = Gem::Specification.find_by_name("migrate")
  return @@debug_mode ? ".." : spec.path
end 

def red(text); colorize(text, 31); end
def green(text); colorize(text, 32); end
def yellow(text); colorize(text, 33); end
end 