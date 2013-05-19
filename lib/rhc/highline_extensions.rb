require 'delegate'

#
# Add specific improved functionality
#
class HighLineExtension < HighLine
  [:ask, :agree].each do |sym|
    define_method(sym) do |*args, &block|
      separate_blocks
      r = super(*args, &block)
      @last_line_open = false
      r
    end
  end

  # OVERRIDE
  def say(msg)
    if msg.respond_to? :to_str
      separate_blocks

      statement = msg.to_str
      return statement unless statement.present?

      template  = ERB.new(statement, nil, "%")
      statement = template.result(binding)

      if @wrap_at
        statement = statement.textwrap_ansi(@wrap_at, false)
        if @last_line_open && statement.length > 1
          @last_line_open = false
          @output.puts
        end
        statement = statement.join("#{indentation}\n") 
      end
      statement = send(:page_print, statement) unless @page_at.nil?

      @output.print(indentation) unless @last_line_open

      @last_line_open = 
        if statement[-1, 1] == " " or statement[-1, 1] == "\t"
          @output.print(statement)
          @output.flush
          statement.strip_ansi.length + (@last_line_open || 0)
        else
          @output.puts(statement)
          false
        end

    elsif msg.respond_to? :each
      separate_blocks

      @output.print if @last_line_open
      @last_line_open = false

      color = msg.color if msg.respond_to? :color
      @output.print HighLine::Style(color).code if color

      msg.each do |s|
        @output.print indentation
        @output.puts s
      end

      @output.print HighLine::CLEAR if color
      @output.flush      
    end

    msg
  end

  # given an array of arrays "items", construct an array of strings that can
  # be used to print in tabular form.
  def table(items, opts={}, &block)
    items = items.map(&block) if block_given?
    opts[:width] ||= default_max_width
    Table.new(items, opts)
  end

  def table_args(indent=nil, *args)
    opts = {}
    opts[:indent] = indent
    opts[:width] = [default_max_width, *args]
    opts
  end

  def default_max_width
    @wrap_at ? @wrap_at - indentation.length : nil
  end

  def header(str,opts = {}, &block)
    say Header.new(str, default_max_width, '  ')
    if block_given?
      indent &block
    end
  end

  #:nocov:
  # Backport from Highline 1.6.16
  unless HighLine.method_defined? :indent
    #
    # Outputs indentation with current settings
    #
    def indentation
      @indent_size ||= 2
      @indent_level ||= 0
      return ' '*@indent_size*@indent_level
    end

    #
    # Executes block or outputs statement with indentation
    #
    def indent(increase=1, statement=nil, multiline=nil)
      @indent_size ||= 2
      @indent_level ||= 0
      @indent_level += increase
      multi = @multi_indent
      @multi_indent = multiline unless multiline.nil?
      if block_given?
          yield self
      else
          say(statement)
      end
    ensure
      @multi_indent = multi
      @indent_level -= increase
    end
  end 
  #:nocov:

  ##
  # section
  #
  # highline helper mixin which correctly formats block of say and ask
  # output to have correct margins.  section remembers the last margin
  # used and calculates the relitive margin from the previous section.
  # For example:
  #
  # section(bottom=1) do
  #   say "Hello"
  # end
  #
  # section(top=1) do
  #   say "World"
  # end
  #
  # Will output:
  #
  # > Hello
  # >
  # > World 
  #
  # with only one newline between the two.  Biggest margin wins.
  #
  # params:
  #  top - top margin specified in lines
  #  bottom - bottom margin specified in line
  #
  def section(params={}, &block)
    top = params[:top] || 0
    bottom = params[:bottom] || 0

    # the first section cannot take a newline
    top = 0 unless @margin
    @margin = [top, @margin || 0].max

    value = block.call

    say "\n" if @last_line_open
    @margin = [bottom, @margin].max

    value
  end

  ##
  # paragraph
  #
  # highline helper which creates a section with margins of 1, 1
  #
  def paragraph(&block)
    section(:top => 1, :bottom => 1, &block)
  end

  def pager
    #:nocov:
    return if RHC::Helpers.windows?
    return unless @output.tty?

    read, write = IO.pipe

    unless Kernel.fork # Child process
      STDOUT.reopen(write)
      STDERR.reopen(write) if STDERR.tty?
      read.close
      write.close
      return
    end

    # Parent process, become pager
    STDIN.reopen(read)
    read.close
    write.close

    ENV['LESS'] = 'FSRX' # Don't page if the input is short enough

    Kernel.select [STDIN] # Wait until we have input before we start the pager
    pager = ENV['PAGER'] || 'less'
    exec pager rescue exec "/bin/sh", "-c", pager
    #:nocov:
  end

  private
    def separate_blocks
      if (@margin ||= 0) > 0 && !@last_line_open
        @output.print "\n" * @margin
        @margin = 0
      end
    end
end

#
# An element capable of being split into multiple logical rows
#
module RowBased
  extend Forwardable
  def_delegators :rows, :each, :to_a, :join
  alias_method :each_line, :each
end

class HighLine::Header < Struct.new(:text, :width, :indent, :color)
  include RowBased

  protected
    def rows
      @rows ||= begin
        if !width || width == 0
          [text.is_a?(Array) ? text.join(' ') : text]

        elsif text.is_a? Array
          widths = text.map{ |s| s.strip_ansi.length }
          chars, join, indented = 0, 1, (indent || '').length
          narrow = width - indented
          text.zip(widths).inject([]) do |rows, (section, w)|
            if rows.empty?
              if w > width
                rows.concat(section.textwrap_ansi(width))
              else
                rows << section.dup
                chars += w
              end
            else
              if w + chars + join > narrow
                rows.concat(section.textwrap_ansi(narrow).map{ |s| "#{indent}#{s}" })
                chars = 0
              elsif chars == 0
                rows << "#{indent}#{section}"
                chars += w + indented
              else
                rows[-1] << " #{section}"
                chars += w + join
              end
            end
            rows
          end
        else
          text.textwrap_ansi(width)
        end
      end.tap do |rows|
        rows << '-' * rows.map{ |s| s.strip_ansi.length }.max
      end
    end
end

#
# Represent a columnar layout of items with wrapping and flexible layout.
# 
class HighLine::Table
  include RowBased

  def initialize(items=nil,options={},&mapper)
    @items, @options, @mapper = items, options, mapper
  end

  def color
    opts[:color]
  end

  protected 
    attr_reader :items

    def opts
      @options
    end

    def align
      opts[:align] || []
    end
    def joiner
      opts[:join] || ' '
    end
    def indent
      opts[:indent] || ''
    end
    def heading
      @heading ||= opts[:heading] ? HighLine::Header.new(opts[:heading], max_width, indent) : nil
    end

    def source_rows
      @source_rows ||= begin
        (@mapper ? (items.map &@mapper) : items).each do |row|
          row.map!{ |col| col.is_a?(String) ? col : col.to_s }
        end
      end
    end

    def headers
      @headers ||= opts[:header] ? [Array(opts[:header])] : []
    end

    def columns
      @columns ||= source_rows.map(&:length).max || 0
    end

    def column_widths
      @column_widths ||= begin
        widths = Array.new(columns){ Width.new(0,0,0) }
        (source_rows + headers).each do |row|
          row.each_with_index do |col, i|
            w = widths[i]
            s = col.strip_ansi
            word_length = s.scan(/\b\S+/).inject(0){ |l, word| l = word.length if l <= word.length; l }
            w.min = word_length unless w.min > word_length
            w.max = s.length unless w.max > s.length
          end
        end
        widths
      end
    end

    Width = Struct.new(:min, :max, :set)

    def allocate_widths_for(available)
      available -= (columns-1) * joiner.length + indent.length
      return column_widths.map{ |w| w.max } if available >= column_widths.inject(0){ |sum, w| sum + w.max } || column_widths.inject(0){ |sum, w| sum + w.min } > available

      fair = available / columns
      column_widths.each do |w|
        if w.set > 0
          available -= w.set
          next
        end
        w.set = if w.max <= fair
            available -= w.max
            w.max
          else
            0
          end
      end

      remaining = column_widths.inject(0){ |sum, w| if w.set == 0; sum += w.max; available -= w.min; end; sum }
      fair = available.to_f / remaining.to_f

      column_widths.
        each do |w| 
          if w.set == 0
            available -= (alloc = (w.max * fair).to_i)
            w.set = alloc + w.min
          end
        end.
        each{ |w| if available > 0 && w.set < w.max; w.set += 1; available -= 1; end }.
        map(&:set)
    end

    def widths
      @widths ||= begin
        case w = opts[:width]
        when Array
          column_widths.zip(w[1..-1]).each do |width, col| 
            width.set = col || 0
            width.max = width.set if width.set > width.max
          end
          allocate_widths_for(w.first || 0)
        when Integer
          allocate_widths_for(w)
        else
          column_widths.map{ |w| w.max }
        end
      end
    end

    def max_width
      @max_width ||= opts[:width].is_a?(Array) ? opts[:width].first : (opts[:width] ? opts[:width] : 0)
    end

    def header_rows
      @header_rows ||= begin
        headers << widths.map{ |w| '-' * w } if headers.present?
        headers
      end
    end

    def rows
      @rows ||= begin
        body = (header_rows + source_rows).inject([]) do |a,row| 
          row = row.zip(widths).map{ |column,w| w && w > 0 ? column.textwrap_ansi(w, false) : [column] }
          (row.map(&:length).max || 0).times do |i|
            s = []
            row.each_with_index do |lines, j|
              cell = lines[i]
              l = cell ? cell.strip_ansi.length : 0
              s << 
                  if align[j] == :right 
                    "#{' '*(widths[j]-l) if l < widths[j]}#{cell}"
                  else
                    "#{cell}#{' '*(widths[j]-l) if l < widths[j]}"
                  end
            end
            a << "#{indent}#{s.join(joiner).rstrip}"
          end
          a
        end
        
        body = heading.to_a.concat(body) if heading
        body
      end
    end
end

$terminal = HighLineExtension.new
$terminal.indent_size = 2 if $terminal.respond_to? :indent_size
