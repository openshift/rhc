#!/usr/bin/env ruby
# Copyright 2012 Red Hat, Inc.

require 'test/unit'
require 'tempfile'
require 'parseconfig'
require 'rhc-common'

class TestConfigFile < Test::Unit::TestCase
  def write_config_file(lines)
    file = Tempfile.new('test')

    File.open(file.path,'w') do |f|
      lines.each do |line|
        f.puts line.lstrip
      end
    end
    file
  ensure
    file.close
  end

  # These tests check config file parsing
  #   They ensure that we can do to and from the config file format properly
  def check_parse_config_file(str,hash)
    file = write_config_file(str.lines)

    vars = current_vars(file.path)
    assert_equal(hash,vars)
  end

  def test_conf_file_empty
    hash = {}
    string = ''
    check_parse_config_file(string,hash)
  end

  def test_conf_file_comment
    hash = {
      :foo => {
        :values => [
          {:val => 'bar', :commented => true}
        ]
      }
    }
    string = <<-STR
      #foo = bar
    STR
    check_parse_config_file(string,hash)
  end

  def test_conf_file_single
    hash = {
      :foo => {
        :values => [
          {:val => 'bar', :commented => false}
        ]
      }
    }
    string = <<-STR
      foo = bar
    STR
    check_parse_config_file(string,hash)
  end

  def test_conf_file_multiple
    hash = {
      :foo => {
        :values => [
          {:val => 'bar', :commented => true},
          {:val => 'baz', :commented => false}
        ]
      }
    }
    string = <<-STR
      #foo = bar
      foo = baz
    STR
    check_parse_config_file(string,hash)
  end

  # Test how we merge existing config variables with the defaults
  def check_combine(old,new,correct)
    combined = combine_opts(old,new)
    assert_equal(correct,combined)
  end

  def test_combine_no_existing_opts
    old = {}
    new = {
      :bar => {
        :default => "BAR"
      }
    }
    # The correct value should just be the new hash, converted
    correct = {
      :bar => {
        :values => [
          {:val => "BAR", :commented => true}
        ]
      }
    }
    check_combine(old,new,correct)
  end

  def test_combine_merging_opts
    old = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      }
    }
    new = {
      :bar => {
        :default => "BAR"
      }
    }
    correct = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      },
      :bar => {
        :values => [
          { :val => "BAR", :commented => true }
        ],
      }
    }

    check_combine( old, new, correct)
  end

  def test_combine_existing_opts
    old = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      }
    }
    new = {
      :foo => {
        :default => "BAR"
      }
    }
    correct = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      },
    }

        check_combine( old, new, correct)
  end

  def test_combine_existing_commented_opts
    old = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => true }
        ],
      }
    }
    new = {
      :foo => {
        :default => "BAR"
      }
    }
    correct = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => true }
        ],
      },
    }

        check_combine( old, new, correct)
  end

  def test_combine_existing_opts_adding_comments
    old = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      }
    }
    new = {
      :foo => {
        :default => "BAR",
        :comment => "ASDF"
      }
    }
    correct = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false },
        ],
        :comment => "ASDF"
      },
    }

    check_combine( old, new, correct)
  end

  def test_combine_existing_opts_and_add_new
    old = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      }
    }
    new = {
      :foo => {
        :default => "BAZ"
      },
      :bar => {
        :default => "BAR"
      }
    }
    correct = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      },
      :bar => {
        :values => [
          { :val => "BAR", :commented => true }
        ],
      },
    }

        check_combine( old, new, correct)
  end

  # Test generating values for config files
  def test_config_value
    vals = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      }
    }
    string = ["foo = FOO"]
    assert_equal string, to_config_array(vals)
  end

  def test_config_value_commented
    vals = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => true }
        ],
      }
    }
    string = ["#foo = FOO"]
    assert_equal string, to_config_array(vals)
  end

  def test_config_value_with_comment
    vals = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false },
        ],
        :comment => "This is a comment"
      }
    }
    string = ["# This is a comment\nfoo = FOO"]
    assert_equal string, to_config_array(vals)
  end

  def test_config_value_with_multiline_comment
    vals = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false },
        ],
        :comment => ["This is a multiline comment","This is the second line"]
      }
    }
    string = ["# This is a multiline comment\n# This is the second line\nfoo = FOO"]
    assert_equal string, to_config_array(vals)
  end

  def test_config_multiple_values
    vals = {
      :foo => {
        :values => [
          { :val => "FOO", :commented => false }
        ],
      },
      :bar => {
        :values => [
          { :val => "BAR", :commented => true }
        ],
      },
    }
        string = ["#bar = BAR","foo = FOO"]
        assert_equal string, to_config_array(vals)
  end

  def check_write_config_file(lines,str = nil)
    file = Tempfile.new('test')
    status = write_config(lines,file.path)

    if str
      File.open(file.path) do |f|
        # Make sure to string the space from the front of the string but leave newlines
        string = str.lines.map{|line| line =~ /^\n$/ ? line : line.lstrip  }
        assert_equal string, f.readlines
      end
    end

    [file,status]
  ensure
    file.close
  end

  def test_writing_config
    lines = [
      "foo = bar",
      "#comment = baz"
    ]
    str = <<-STR
    foo = bar

    #comment = baz
    STR

    check_write_config_file(lines,str)
  end

  def test_writing_new_config
    lines = [
      "foo = bar",
      "#comment = baz"
    ]
    (file,status) = check_write_config_file(lines)

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
    lines = [
      "foo = bar",
      "#comment = baz"
    ]
    (file,status) = check_write_config_file(lines)
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
    lines = [
      "foo = bar",
      "#comment = baz"
    ]
    (file,status) = check_write_config_file(lines)
    lines << "new = line"
    status = write_config(lines,file.path)

    # Make sure the file is created
    assert_equal MODIFIED, status
    # Make sure no backup file is made
    assert File.exists?("#{file.path}.bak"), "backup config file should exist"
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
