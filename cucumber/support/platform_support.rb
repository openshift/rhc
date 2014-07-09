if $target_os == 'fedora-19'
  CARTRIDGE_MAP = {
      "php"         => { type: "php-5.5", name: "PHP 5.5" },
      "mysql"       => { type: "mariadb-5.5", name: "MariaDB 5.5" },
      "phpmyadmin"  => { type: "phpmyadmin-3", name: "phpMyAdmin 3.5" },
      "mongodb"     => { type: "mongodb-2.4", name: "MongoDB 2.4" },
      "postgresql"  => { type: "postgresql-9.2", name: "PostgreSQL 9.2" },
      "cron"        => { type: "cron-1.4", name: "Cron 1.4" },
      "haproxy"     => { type: "haproxy-1.4", name: "" }
  }
else
  CARTRIDGE_MAP = {
    "php"         => { type: "php-5.3", name: "PHP 5.3" },
    "mysql"       => { type: "mysql-5.1", name: "MySQL 5.1" },
    "phpmyadmin"  => { type: "phpmyadmin-4", name: "phpMyAdmin 4.0" },
    "mongodb"     => { type: "mongodb-2.4", name: "MongoDB 2.4" },
    "postgresql"  => { type: "postgresql-8.4", name: "PostgreSQL 8.4" },
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
