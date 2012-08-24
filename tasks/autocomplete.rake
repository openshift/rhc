require 'rhc/autocomplete'

task :autocomplete do
  autocomplete = RHC::AutoComplete.new
  script = autocomplete.gen
  puts script
end
