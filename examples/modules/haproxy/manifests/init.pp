class haproxy {
  include rsyslog

  package{"haproxy":
    ensure => installed
  }
  service{"haproxy":
    ensure => running,
    require => Package["haproxy"]
  }
  file{"/etc/default/haproxy":
    source => "puppet:///modules/haproxy/default",
    requre => Package["haproxy"],
    notify => Service["haproxy"]
  }
  file{"/etc/rsyslog.d/haproxy.conf":
    source => "puppet:///modules/haproxy/haproxy.rsyslog.conf",
    require => [Package["rsyslog"], Package["haproxy"]],
    notify => Service["rsyslog"]
  }
}