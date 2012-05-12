class Test::Unit::TestCase

  def with_devenv
    omit("Cannot run unless a devenv is specified")

    @random = rand(1000)
    end_point = "https://ec2-23-20-154-157.compute-1.amazonaws.com/broker/rest"
    username = "rhc-rest-test-#{@random}"
    password = "xyz123"
    @client = Rhc::Rest::Client.new(end_point, username, password)
    @domains = []
  end

end
