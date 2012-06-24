$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
