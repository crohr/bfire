class haproxy {
  include rsyslog

  exec{"disable apache2":
    command => "/etc/init.d/apache2 stop",
    user => root
  }

  package{"haproxy":
    ensure => installed,
    require => Exec["disable apache2"]
  }
  service{"haproxy":
    ensure => running,
    require => Package["haproxy"]
  }
  file{"/etc/default/haproxy":
    source => "puppet:///modules/haproxy/default",
    require => Package["haproxy"],
    notify => Service["haproxy"]
  }
  file{"/etc/rsyslog.d/haproxy.conf":
    source => "puppet:///modules/haproxy/haproxy.rsyslog.conf",
    require => [Package["rsyslog"], Package["haproxy"]],
    notify => Service["rsyslog"]
  }
}