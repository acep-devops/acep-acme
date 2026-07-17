golang 'default' do
end

execute 'go install github.com/jsha/minica@latest' do
  env 'PATH' => "/usr/local/go/bin:#{ENV['PATH']}"
end

docker_installation 'default'
docker_service 'default' do
  storage_driver 'vfs'
  action [:create, :start]
end

directory '/etc/pebble' do
  action :create
end

directory '/etc/pebble/certs' do
  action :create
end

execute 'minica -ca-cert pebble.minica.pem -ca-key pebble.minica.key -domains localhost,pebble -ip-addresses 127.0.0.1' do
  cwd '/etc/pebble/certs'
  env 'PATH' => "#{ENV['HOME']}/go/bin:#{ENV['PATH']}"
  # Check for the actual generated domain cert, not the root CA
  not_if { ::File.exist?('/etc/pebble/certs/localhost/cert.pem') }
  action :run
end

file '/etc/pebble/config.json' do
  content <<-EOF
{
  "pebble": {
    "listenAddress": "0.0.0.0:14000",
    "managementListenAddress": "0.0.0.0:15000",
    "certificate": "/test/certs/localhost/cert.pem",
    "privateKey": "/test/certs/localhost/key.pem",
    "httpPort": 80,
    "tlsPort": 443,
    "ocspResponderURL": "",
    "externalAccountBindingRequired": false,
    "domainBlocklist": ["blocked-domain.example"],
    "retryAfter": {
        "authz": 3,
        "order": 5
    },
    "profiles": {
      "default": {
        "description": "The profile you know and love",
        "validityPeriod": 7776000
      },
      "shortlived": {
        "description": "A short-lived cert profile, without actual enforcement",
        "validityPeriod": 518400
      }
    }
  }
}
  EOF
end

docker_image 'ghcr.io/letsencrypt/pebble' do
  tag 'latest'
end

node.default['acme']['endpoint'] = 'https://localhost:14000/dir'

docker_gateway_ip = node['network']['interfaces']['docker0']['addresses'].find { |addr, data| data['family'] == 'inet' }&.first rescue '172.17.0.1'

docker_container 'pebble' do
  repo 'ghcr.io/letsencrypt/pebble'
  tag 'latest'
  port [
    '14000:14000',
    '15000:15000',
  ]

  command '-config /test/config.json'
  volumes [
    '/etc/pebble:/test',
  ]

  env [
    'PEBBLE_VA_NOSLEEP=1',
    'PEBBLE_VA_ALWAYS_VALID=0',
  ]

  extra_hosts ["test.local:#{docker_gateway_ip}"]

  action :run
end

directory Chef::Config[:trusted_certs_dir] do
  action :create
end

chef_client_trusted_certificate 'localhost' do
  certificate lazy { ::File.read('/etc/pebble/certs/pebble.minica.pem') }
  action :add
end

# Needed for the acme-client gem to continue connecting to pebble;
# please do NOT do this on production Chef nodes!
execute 'update Chef trusted certificates store' do
  command "cat /etc/pebble/certs/pebble.minica.pem >> /opt/chef/embedded/ssl/certs/cacert.pem"
  not_if 'grep -q "minica root ca" /opt/chef/embedded/ssl/certs/cacert.pem'
end

execute 'cp /etc/pebble/certs/pebble.minica.pem /usr/local/share/ca-certificates/pebble.minica.crt && update-ca-certificates' do
  creates '/usr/local/share/ca-certificates/pebble.minica.crt'
end
