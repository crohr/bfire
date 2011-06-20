class web {
  include haproxy
  include sinatra

  file{"/tmp/monitor":
    recurse => true,
    source => "puppet:///modules/web/monitor",
    notify => Service["monitorapp"]
  }

  service{"monitorapp":
    ensure => running,
    start => "/usr/bin/thin -d -l /var/log/thin.log -p 8000 -R config.ru -c /tmp/monitor --tag monitorapp start",
    stop => "/usr/bin/thin -d -l /var/log/thin.log -p 8000 -R config.ru -c /tmp/monitor --tag monitorapp stop",
    require => [
      Package["libsinatra-ruby"],
      File["/tmp/monitor"]
    ]
  }
  
  file{"/var/log/haproxy.log":
    ensure => present,
    mode => 644
  }

}