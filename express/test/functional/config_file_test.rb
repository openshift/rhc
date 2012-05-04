#!/usr/bin/env ruby
# Copyright 2012 Red Hat, Inc.

require 'test/unit'
require 'rhc-common'
require 'tempfile'
require 'parseconfig'
require 'yaml'

class TestConfigFile < Test::Unit::TestCase
  def setup
    @hashes = YAML.load_file('test/functional/fixtures.yml')
  end

  def hash_to_temp(hash)
    file = Tempfile.new('test')
    hash.each do |k,v|
      file.puts "%s%s = %s" % [(v[:commented] ? "#":""), k,v[:val]]
    end
    file
  ensure
    file.close
  end

  # These tests check config file parsing
  #   They ensure that we can do to and from the config file format properly
  def check_hash(hash)
    # Need to remove the comment from our test fixture since it doesn't get parsed
    hash.each do |k,v|
      v.delete(:comment)
    end
    conf = hash_to_temp(hash)
    vars = current_vars(conf.path)
    assert_equal(hash,vars)
  end

  def test_conf_file_empty
    hash = @hashes[:empty]
    check_hash(hash)
  end

  def test_conf_file_valid
    hash = @hashes[:a][:hash]
    check_hash(hash)
  end

  def test_conf_file_comment
    hash = @hashes[:b][:hash]
    check_hash(hash)
  end

  # Test how we merge existing config variables with the defaults
  def check_combine(old,new,correct)
    combined = combine_opts(old,new)
    assert_equal(correct,combined)
  end

  def test_no_existing_opts
    hash = @hashes[:b]

    old = @hashes[:empty]
    new = { :bar => hash[:default] }

    # The correct value should just be the new hash, converted
    correct = hash[:hash]

    check_combine(old,new,correct)
  end

  def test_combine_opts
    old = @hashes[:a][:hash]
    new = @hashes[:b]

    # The correct value should just be both hashes, with the new converted
    correct = old
    correct[:bar] = new[:hash][:bar]

    check_combine(
      old,
      { :bar => new[:default] },
      correct
    )
  end

  def test_keeping_existing_value_and_adding_comment
    old = @hashes[:a][:hash]
    new = @hashes[:b]

    # The correct value should be the old value with the new comment added to it
    correct = old
    correct[:foo][:comment] = new[:default][:comment]

    check_combine(
      old,
      { :foo => new[:hash][:bar] },
      correct
    )
  end

  def test_keeping_existing_value_and_adding_another_option
    old = @hashes[:a][:hash]
    new = @hashes[:b]
    added = @hashes[:b]

    # The correct value should be the old value with
    #   - the new comment added to it
    #   - the second value added to it
    correct = old
    correct[:bar] = added[:hash][:bar]
    correct[:foo][:comment] = new[:default][:comment]

    check_combine(
      old,
      {
        :foo => new[:hash][:bar],
        :bar => added[:default]
      },
      correct
    )
  end

  # Test generating values for config files
  def test_config_value
    hash = @hashes[:a]
    string = hash[:string]
    vals = hash[:hash]

    assert_equal string, to_config_array(vals)
  end

  def test_config_value_commented_out
    hash = @hashes[:b]
    string = hash[:string]
    vals = hash[:hash]

    assert_equal string, to_config_array(vals)
  end

  def test_config_multiple_values
    a = @hashes[:a]
    b = @hashes[:b]

    vals = {}
    vals.merge!(a[:hash])
    vals.merge!(b[:hash])

    # This has to be alphabetical by key
    string = []
    string << b[:string]
    string << a[:string]
    string.flatten!

    assert_equal string, to_config_array(vals)
  end

  # Test writing config files
  def test_writing_config
    file = Tempfile.new('foobar')
    file.close

    a = @hashes[:a]
    b = @hashes[:b]

    lines = a[:string]
    lines << b[:string]

    status = write_config(lines,file.path)

    # Make sure the format matches
    config = file.open.read
    assert_equal "#{lines.join("\n"*2)}\n",config
  ensure
    file.close
  end

  def test_writing_new_config
    file = Tempfile.new('foobar')
    file.close

    a = @hashes[:a]
    b = @hashes[:b]

    lines = a[:string]
    lines << b[:string]

    status = write_config(lines,file.path)

    # Make sure the file is created
    assert_equal CREATED, status
    # Make sure no backup file is made
    assert !File.exists?("#{file.path}.bak"), "backup config file exists when it shouldn't"
  ensure
    begin
      File.delete("#{file.path}.bak")
    rescue
    end
  end

  def test_writing_same_config
    file = Tempfile.new('foobar')
    file.close

    a = @hashes[:a]
    b = @hashes[:b]

    lines = a[:string]
    lines << b[:string]

    write_config(lines,file.path)
    status = write_config(lines,file.path)

    # Make sure the file is created
    assert_equal UNCHANGED, status
    # Make sure no backup file is made
    assert !File.exists?("#{file.path}.bak"), "backup config file exists when it shouldn't"
  ensure
    begin
      File.delete("#{file.path}.bak")
    rescue
    end
  end

  def test_writing_updated_config
    file = Tempfile.new('foobar')
    file.close

    a = @hashes[:a]
    b = @hashes[:b]

    lines = []
    lines << a[:string]
    lines << b[:string]

    # Write the original config
    write_config(lines,file.path)

    new_lines = lines.map do |line|
      [line.join('').gsub(/comment/,"COMMENT")]
    end

    status = write_config(new_lines,file.path)

    # Make sure the file is created
    assert_equal MODIFIED, status
    # Make sure no backup file is made
    assert File.exists?("#{file.path}.bak"), "backup config file exists when it shouldn't"
  ensure
    begin
      File.delete("#{file.path}.bak")
    rescue
    end
  end

  # Tying it all together
  def test_full_workflow
    file = Tempfile.new('foobar')
    file.close

    a = @hashes[:a]

    opts = {
      :foo => {
        :default => "FOO",
        :comment => ["This is a comment"]
      },
      :bar => {
        :default => "BAR",
        :comment => ["This is a comment"]
      }
    }

    # Create the first config file
    state = create_local_config(file.path,opts)
    assert_equal CREATED, state

    # Make sure no variables actually exist
    vals = ParseConfig.new(file.path)
    assert vals.params.empty?, "Config should not have any values set"

    # Manually change the foo variable
    newlines = []
    File.open(file.path) do |file|
      newlines = file.lines.map do |line|
        line.gsub(/^#foo = FOO/,'foo = ASDF')
      end
    end
    File.open(file.path,"w") do |file|
      file.puts newlines
    end

    # Make sure the value is changed
    vals = ParseConfig.new(file.path)
    assert_equal "ASDF", vals.params['foo']

    # Update the config file and make sure it isn't affected
    state = create_local_config(file.path,opts)
    assert_equal UNCHANGED, state
    vals = ParseConfig.new(file.path)
    assert_equal "ASDF", vals.params['foo']

    # Add a variable
    opts[:new] = {
      :default => "NEW VAR",
      :comment => ["This is a new comment"]
    }

    # check how many lines we have
    old_lines = File.open(file.path){|x| x.readlines.length }
    state = create_local_config(file.path,opts)
    new_lines = File.open(file.path){|x| x.readlines.length }
    assert_equal 3, new_lines - old_lines, "Incorrect number of lines added"

    assert_equal "ASDF", vals.params['foo']
    assert_nil vals.params['new']
  end
end
