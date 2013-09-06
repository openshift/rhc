module RHC::Auth
  autoload :Basic,      'rhc/auth/basic'
  autoload :Token,      'rhc/auth/token'
  autoload :TokenStore, 'rhc/auth/token_store'
  autoload :Negotiate,  'rhc/auth/negotiate'
end
