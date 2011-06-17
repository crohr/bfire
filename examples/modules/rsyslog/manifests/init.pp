class rsyslog {
  package{"rsyslog":
    ensure => installed
  }
  service{"rsyslog":
    name => "rsyslogd",
    ensure => running,
    require => Package["rsyslog"]
  }
  
  file{"/etc/rsyslog.conf":
    source => "puppet:///modules/rsyslog/rsyslog.conf",
    require => Package["rsyslog"],
    notify => Service["rsyslog"]
  }
}