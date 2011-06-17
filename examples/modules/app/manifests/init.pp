class app {
  include sinatra
  
  file{"/tmp/app":
    recurse => true,
    source => "puppet:///modules/app/app"
  }

  exec{"launch app":
    command => "/usr/bin/thin -d -l /var/log/thin.log -p 80 -R config.ru -c /tmp/app start",
    require => Package["libsinatra-ruby"]
  }
}