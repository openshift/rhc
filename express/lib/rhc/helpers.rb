require 'commander/user_interaction'

module RHC::Helpers
  # helpers always have Commander UI available
  include Commander::UI
  include Commander::UI::AskForClass

  extend self

  def decode_json(s)
    Rhc::Vendor::OkJson.decode(s)
  end

  def date(s)
    now = Time.now
    d = datetime_rfc3339(s)
    if now.year == d.year
      return d.strftime('%l:%M %p').strip if now.yday == d.yday
    end
    d.strftime('%b %d %l:%M %p')
  end

  def datetime_rfc3339(s)
    DateTime.strptime(s, '%Y-%m-%dT%H:%M:%S%z')
    # Replace with d = DateTime.rfc3339(s)
  end

  def openshift_server
    ENV['LIBRA_SERVER'] || 'openshift.redhat.com'
  end

  def success(*args)
    args.each{ |a| say color(a, :green) }
  end
  def warn(*args)
    args.each{ |a| say color(a, :yellow) }
  end

  def color(s, color)
    $terminal.color(s, color)
  end

  def pluralize(count, s)
    count == 1 ? "#{count} #{s}" : "#{count} #{s}s"
  end

  def table(items, opts={}, &block)
    items = items.map &block if block_given?
    columns = []
    max = items.each do |item|
      item.each_with_index do |s, i|
        item[i] = s.to_s
        columns[i] = [columns[i] || 0, s.length].max if s.respond_to?(:length)
      end
    end
    align = opts[:align] || []
    join = opts[:join] || ' '
    items.map do |item|
      item.each_with_index.map{ |s,i| s.send((align[i] == :right ? :rjust : :ljust), columns[i], ' ') }.join(join).strip
    end
  end
end
