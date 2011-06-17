class apache2 {
  include "apache2::${operatingsystem}"
}

# Class: apache2::debian
#
#
class apache2::debian {
  package { "apache2":
    ensure  => installed,
  }
  
  service { "apache2":
    ensure  => running,
    enable  => true,
    require => Package["apache2"];
  }
}

# Class: apache2::ubuntu
#
#
class apache2::ubuntu {
  include apache2::debian
}

# Class: apache2::centos
#
#
class apache2::centos {
  package { "httpd":
    ensure  => installed,
  }
  
  service { "httpd":
    ensure  => running,
    enable  => true,
    require => Package["httpd"];
  }
}




