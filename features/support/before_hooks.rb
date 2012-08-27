{
  :application => 'we have a running php-5.3 application without an embedded cartridge',
  :domain => 'we have an existing domain',
  :client => 'we have the client tools setup',
  :single_cartridge => 'we have a running php-5.3 application with an embedded mysql-5.1 cartridge',
  :multiple_cartridge => 'we have a running php-5.3 application with embedded mysql-5.1 and phpmyadmin-3.4 cartridges',
}.each do |tag,assumption|
  Before("@#{tag}",'~@init') do
    Given assumption
  end
end
