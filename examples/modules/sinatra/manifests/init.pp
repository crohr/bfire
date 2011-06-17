class sinatra {
  package{"libsinatra-ruby":
    ensure => installed,
    require => Package["thin"]
  }
  package{"thin":
    ensure => installed
  }
}