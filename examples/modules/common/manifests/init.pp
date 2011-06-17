class common {
  package{"curl":
    ensure => installed
  }
  package{"vim":
    ensure => installed
  }
}