class web {
  include haproxy
  include sinatra

  file{"/srv/monitor":
    recurse => true,
    source => "puppet:///modules/web/monitor",
    notify => Service["monitorapp"]
  }

  service{"monitorapp":
    ensure => running,
    start => "/usr/bin/thin -d -l /var/log/thin.log -p 8000 -R config.ru -c /srv/monitor --tag monitorapp start",
    stop => "/usr/bin/thin -d -l /var/log/thin.log -p 8000 -R config.ru -c /srv/monitor --tag monitorapp stop",
    require => [
      Package["libsinatra-ruby"],
      File["/srv/monitor"],
      Service["haproxy"]
    ]
  }
  
  file{"/var/log/haproxy.log":
    ensure => present,
    mode => 644
  }

}