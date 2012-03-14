class app {
  include sinatra
  
  package{"stress":
    ensure => installed
  }
  
  file{"/tmp/app":
    recurse => true,
    source => "puppet:///modules/app/app",
    notify => Service["myapp"]
  }

  exec{"disable apache2":
    command => "/etc/init.d/apache2 stop",
    user => root
  }

  service{"myapp":
    ensure => running,
    start => "/usr/bin/thin -d -l /var/log/thin.log -p 80 -R config.ru -c /tmp/app --tag myapp start",
    stop => "/usr/bin/thin -d -l /var/log/thin.log -p 80 -R config.ru -c /tmp/app --tag myapp stop",
    require => [
      Package["libsinatra-ruby"],
      Package["stress"],
      File["/tmp/app"],
      Exec["disable apache2"]
    ]
  }
}