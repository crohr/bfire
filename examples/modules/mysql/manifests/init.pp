class mysql {
  include "mysql::${operatingsystem}"
}

# Class: mysql::debian
#
#
class mysql::debian {
  package { "mysql-server":
    ensure  => installed,
  }
  
  service { "mysql":
    ensure  => running,
    enable  => true,
    require => Package["mysql-server"];
  }
}

# Class: mysql::ubuntu
#
#
class mysql::ubuntu {
  include mysql::debian
}

# Class: mysql::centos
#
#
class mysql::centos {
  package { "mysql-server":
    ensure  => installed,
  }
  
  service { "mysqld":
    ensure  => running,
    enable  => true,
    require => Package["mysql-server"];
  }
}
