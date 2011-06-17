class web {
  include haproxy
  include sinatra

  file{"/tmp/monitor":
    recurse => true,
    source => "puppet:///modules/web/monitor"
  }

  exec{"launch monitor app":
    command => "/usr/bin/thin -d -l /var/log/thin.log -p 8000 -R config.ru -c /tmp/monitor start",
    require => Package["libsinatra-ruby"]
  }

}