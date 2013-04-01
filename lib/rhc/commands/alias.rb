require 'rhc/commands/base'
require 'rhc/config'

module RHC::Commands
  class Alias < Base
    summary "Add or remove a custom domain name (alias) for the application"
    syntax "<command> <application> <alias> [--namespace namespace]"
    default_action :help

    summary "Add a custom domain name for the application"
    syntax "<application> <alias> [--namespace namespace]"
    argument :app, "Application name (required)", ["-a", "--app name"], :context => :app_context, :required => true
    argument :app_alias, "Custom domain name for the application", []
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    alias_action :"app add-alias", :root_command => true, :deprecated => true
    def add(app, app_alias)
      rest_app = rest_client.find_application(options.namespace, app)
      rest_app.add_alias(app_alias)
      success "Alias '#{app_alias}' has been added."
      0
    end

    summary "Remove a custom domain name for the application"
    syntax "<application> <alias> [--namespace namespace]"
    argument :app, "Application name (required)", ["-a", "--app name"], :context => :app_context, :required => true
    argument :app_alias, "Custom domain name for the application", []
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    alias_action :"app remove-alias", :root_command => true, :deprecated => true
    def remove(app, app_alias)
      rest_app = rest_client.find_application(options.namespace, app)
      rest_app.remove_alias(app_alias)
      success "Alias '#{app_alias}' has been removed."
      0
    end

    summary "Add or change the SSL certificate for an existing alias"
    description <<-DESC 
      Add or update the SSL certificate for your custom domain alias to 
      allow secure HTTPS communication with your app.

      Certificate files must be Base64 PEM-encoded and typically have a
      .crt or .pem extension. You may combine multiple certificates and
      certificate chains in a single file. The RSA or DSA private key 
      must always be provided in a separate file.

      Pass phrase for the certificate private key is required if the 
      provided private key is encrypted.
    DESC
    syntax "<application> <alias> --certificate FILE --private-key FILE [--passphrase passphrase]"
    argument :app, "Application name (required)", ["-a", "--app name"], :context => :app_context, :required => true
    argument :app_alias, "Custom domain name for the application (required)", []
    option ["--certificate FILE"], "SSL certificate filepath (file in .crt or .pem format)", :required => true
    option ["--private-key FILE"], "Private key filepath for the given SSL certificate", :required => true
    option ["--passphrase passphrase"], "Private key pass phrase, required if the private key is encripted", :required => false
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    def update_cert(app, app_alias)
      certificate_file_path = options.certificate
      raise ArgumentError, "Certificate file not found: #{certificate_file_path}" if !File.exist?(certificate_file_path) || !File.file?(certificate_file_path)

      private_key_file_path = options.private_key
      raise ArgumentError, "Private key file not found: #{private_key_file_path}" if !File.exist?(private_key_file_path) || !File.file?(private_key_file_path)

      certificate_content = File.read(certificate_file_path)
      raise ArgumentError, "Invalid certificate file: #{certificate_file_path} is empty" if certificate_content.to_s.strip.length == 0

      private_key_content = File.read(private_key_file_path)
      raise ArgumentError, "Invalid private key file: #{private_key_file_path} is empty" if private_key_content.to_s.strip.length == 0

      rest_app = rest_client.find_application(options.namespace, app)
      rest_alias = rest_app.find_alias(app_alias)
      if rest_client.api_version_negotiated >= 1.4
        rest_alias.add_certificate(certificate_content, private_key_content, options.passphrase)
        success "SSL certificate successfully added."
        0
      else
        raise RHC::Rest::SslCertificatesNotSupported, "The server does not support SSL certificates for custom aliases."
      end
    end

    summary "Delete the SSL certificate from an existing alias"
    syntax "<application> <alias>"
    argument :app, "Application name (required)", ["-a", "--app name"], :context => :app_context, :required => true
    argument :app_alias, "Custom domain name for the application (required)", []
    option ["--confirm"], "Pass to confirm deleting the application"
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    def delete_cert(app, app_alias)
      rest_app = rest_client.find_application(options.namespace, app)
      rest_alias = rest_app.find_alias(app_alias)
      if rest_client.api_version_negotiated >= 1.4
        confirm_action "#{color("This is a non-reversible action! Your SSL certificate will be permanently deleted from application '#{app}'.", :yellow)}\n\nAre you sure you want to delete the SSL certificate?"
        rest_alias.delete_certificate
        success "SSL certificate successfully deleted."
        0
      else
        raise RHC::Rest::SslCertificatesNotSupported, "The server does not support SSL certificates for custom aliases."
      end
    end

    summary "List the aliases on an application"
    syntax "<application>"
    argument :app, "Application name (required)", ["-a", "--app name"], :context => :app_context, :required => true
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    def list(app)
      rest_app = rest_client.find_application(options.namespace, app)
      items = rest_app.aliases.map do |a|
        a.is_a?(String) ?
          [a, 'no', '-'] :
          [a.id, a.has_private_ssl_certificate? ? 'yes' : 'no', a.has_private_ssl_certificate? ? Date.parse(a.certificate_added_at) : '-']
      end
      if items.empty?
        info "No aliases associated with the application #{app}."
      else
        say table(items, :header => ["Alias", "Has Certificate?", "Certificate Added"])
      end
      0
    end

  end
end
