class rsyslog {
  package{"rsyslog":
    ensure => installed
  }
  service{"rsyslog":
    ensure => running,
    require => Package["rsyslog"]
  }
  
  file{"/etc/rsyslog.conf":
    source => "puppet:///modules/rsyslog/rsyslog.conf",
    require => Package["rsyslog"],
    notify => Service["rsyslog"]
  }
}