module RHC::Auth
  autoload :Basic,      'rhc/auth/basic'
  autoload :X509,       'rhc/auth/x509'
  autoload :Token,      'rhc/auth/token'
  autoload :TokenStore, 'rhc/auth/token_store'
end
