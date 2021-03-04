class { '::apache':
  default_vhost  => false,
  service_manage => false,
  use_systemd    => false,
}

apache::vhost { 'localhost':
  port    => '80',
  docroot => '/var/www/html',
}

file { '/var/www/html/index.html':
  ensure  => present,
  content => 'Hello World',
}

pache::vhost { 'readme.example.net':
  docroot     => '/var/www/readme',
  directories => [
    {
      'path'         => '/var/www/readme',
      'ServerTokens' => 'prod' ,
    },
    {
      'path'  => '/usr/share/empty',
      'allow' => 'from all',
    },
  ],
}

# location test
apache::vhost { 'location.example.net':
  docroot     => '/var/www/location',
  directories => [
    {
      'path'         => '/location',
      'provider'     => 'location',
      'ServerTokens' => 'prod'
    },
  ],
}
