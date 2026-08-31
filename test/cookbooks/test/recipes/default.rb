# use for haproxy debugging with stats
# echo "show stat json" | sudo socat stdio /var/run/haproxy.sock | jq .
package 'socat'
package 'jq'
package 'hatop'

hostsfile_entry '127.0.0.1' do
  hostname 'test.local'
  aliases  ['secondary-test.local']
  action   :append
end

directory '/etc/ssl/private' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# Create self-signed certificate to allow haproxy to start initially
openssl_x509_certificate '/etc/ssl/private/selfsigned.pem' do
  common_name 'test.local'
  org 'ACEP'
  org_unit 'DevOps'
  country 'US'
  expire 365
  subject_alt_name ['IP:127.0.0.1', 'DNS:test.local', 'DNS:secondary-test.local']
  not_if { ::File.exist?('/etc/ssl/private/selfsigned.pem') }
  notifies :run, 'execute[combine selfsigned certs]', :immediately
end

execute 'combine selfsigned certs' do
  command 'cat /etc/ssl/private/selfsigned.pem /etc/ssl/private/selfsigned.key > /etc/ssl/private/test.local.pem'
  action :nothing
end

haproxy_install 'package'

haproxy_config_global '' do
  chroot '/var/lib/haproxy'
  user 'haproxy'
  group 'haproxy'
end

haproxy_config_defaults 'defaults' do
  mode 'http'
  timeout connect: '5000ms',
          client: '50000ms',
          server: '50000ms'
  extra_options(
    errorfile: [
      '400 /etc/haproxy/errors/400.http',
      '403 /etc/haproxy/errors/403.http',
      '408 /etc/haproxy/errors/408.http',
      '500 /etc/haproxy/errors/500.http',
      '502 /etc/haproxy/errors/502.http',
      '503 /etc/haproxy/errors/503.http',
      '504 /etc/haproxy/errors/504.http',
    ]
  )
  haproxy_retries 3
end

haproxy_frontend 'http' do
  mode 'http'
  bind '*:80'
  acl [
    'is_acme path_beg -i /.well-known/acme-challenge/',
  ]
  extra_options(
    redirect: 'scheme https code 301 unless is_acme '
  )
  use_backend ['certbot if is_acme']
  notifies :reload, 'haproxy_service[haproxy]', :immediately
end

haproxy_frontend 'https' do
  mode 'http'
  bind '*:443 ssl crt /etc/ssl/private/test.local.pem'
  default_backend 'upstream'
  notifies :reload, 'haproxy_service[haproxy]', :immediately
end

haproxy_backend 'certbot' do
  server ['server1 127.0.0.1:5002 maxconn 32']
end

haproxy_backend 'upstream' do
  server ['server1 127.0.0.1:8000 check maxconn 32']
end

haproxy_service 'haproxy' do
  action [:create, :enable, :start]
end

certbot 'test.local' do
  domains ['test.local', 'secondary-test.local']
  email 'uaf-acep-ci@alaska.edu'
  acme_endpoint 'https://127.0.0.1:14000/dir'
  http_01_port 5002
  deploy_hook 'cat $RENEWED_LINEAGE/fullchain.pem $RENEWED_LINEAGE/privkey.pem > /etc/ssl/private/test.local.pem && (systemctl reload haproxy || true)'
  action [:install, :run]
end
