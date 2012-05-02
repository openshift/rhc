require 'yaml'
hashes = {
  :empty => {},
  :a => {
    :hash => {
      :foo => {
        :val => "FOO",
        :comment => ["This is a comment"],
        :commented => false
      }
    },
    :default => {
      :default => "FOO",
      :comment => ["This is a comment"]
    },
    :string => ["# This is a comment\nfoo = FOO"]
  },
  :b => {
    :hash => {
      :bar => {
        :val => "BAR",
        :comment => ["This is a comment"],
        :commented => true
      }
    },
    :default => {
      :default => "BAR",
      :comment => ["This is a comment"]
    },
    :string => ["# This is a comment\n#bar = BAR"]
  }
}

File.open('test/functional/fixtures.yml','w') do |file|
  file.puts YAML.dump(hashes)
end
