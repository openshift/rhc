if $target_os == 'fedora-18'
  CARTRIDGE_MAP = {
    "php"         => { type: "php-5.4", name: "PHP 5.4" },
    "mysql"       => { type: "mysql-5.1", name: "MySQL Database 5.1" },
    "phpmyadmin"  => { type: "phpmyadmin-3", name: "phpMyAdmin 3" },
    "mongodb"     => { type: "mongodb-2.2", name: "MongoDB NoSQL Database 2.2" },
    "postgresql"  => { type: "postgresql-9.2", name: "PostgreSQL Database 9.2" },
    "cron"        => { type: "cron-1.4", name: "Cron 1.4" },
    "haproxy"     => { type: "haproxy-1.4", name: "" }
  }
elsif $target_os == 'fedora-19'
  CARTRIDGE_MAP = {
      "php"         => { type: "php-5.5", name: "PHP 5.5" },
      "mysql"       => { type: "mariadb-5.5", name: "MariaDB 5.5" },
      "phpmyadmin"  => { type: "phpmyadmin-3", name: "phpMyAdmin 3" },
      "mongodb"     => { type: "mongodb-2.2", name: "MongoDB NoSQL Database 2.2" },
      "postgresql"  => { type: "postgresql-9.2", name: "PostgreSQL Database 9.2" },
      "cron"        => { type: "cron-1.4", name: "Cron 1.4" },
      "haproxy"     => { type: "haproxy-1.4", name: "" }
  }
else
  CARTRIDGE_MAP = {
    "php"         => { type: "php-5.3", name: "PHP 5.3" },
    "mysql"       => { type: "mysql-5.1", name: "MySQL Database 5.1" },
    "phpmyadmin"  => { type: "phpmyadmin-3", name: "phpMyAdmin 3" },
    "mongodb"     => { type: "mongodb-2.2", name: "MongoDB NoSQL Database 2.2" },
    "postgresql"  => { type: "postgresql-8.4", name: "PostgreSQL Database 8.4" },    
    "cron"        => { type: "cron-1.4", name: "Cron 1.4" },
    "haproxy"     => { type: "haproxy-1.4", name: "" }    
  }
end

def map_cartridge_type(type)
  CARTRIDGE_MAP[type][:type]
end

def map_cartridge_name(type)
  CARTRIDGE_MAP[type][:name]
end
