# Ensure the tools are installed and we have an account
Before('@account_required') do
  RHCHelper::App.rhc_setup
  RHC::Config.initialize
end

# Ensure we have a domain to work with
Before('@domain_required') do
  Domain.create_if_needed
end

# Create an app if we can't find one
Before('@application_required') do
  type = 'php-5.3'
  @app = App.find_on_fs(type).first || (
    app = App.create_unique(type)
    app.rhc_app_create
    app
  )
end

# Ensure an application is running unless we explicitly want it stopped
Before('@application_required','~@stopped_application') do
  @app.rhc_app_start if @app.is_inaccessible?
end

# Ensure the application is stopped
Before('@application_required','@stopped_application') do
  @app.rhc_app_stop unless @app.is_inaccessible?
end
