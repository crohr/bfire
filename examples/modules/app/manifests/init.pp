class app {
  include sinatra
  
  file{"/tmp/app":
    recurse => true,
    source => "puppet:///modules/app/app",
    notify => Service["myapp"]
  }

  service{"myapp":
    ensure => running,
    start => "/usr/bin/thin -d -l /var/log/thin.log -p 80 -R config.ru -c /tmp/app --tag myapp start",
    stop => "/usr/bin/thin -d -l /var/log/thin.log -p 80 -R config.ru -c /tmp/app --tag myapp stop",
    require => [
      Package["libsinatra-ruby"],
      File["/tmp/app"]
    ]
  }
}