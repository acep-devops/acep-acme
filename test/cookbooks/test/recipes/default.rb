hostsfile_entry '127.0.0.1' do
  hostname 'test.local'
end

directory '/etc/ssl/private' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end


certbot 'test.local' do
  email 'uaf-acep-ci@alaska.edu'
  acme_endpoint 'https://127.0.0.1:14000/dir'
  http_01_port 5002
  deploy_hook "cat $RENEWED_LINEAGE/fullchain.pem $RENEWED_LINEAGE/privkey.pem > /etc/ssl/private/fullchain.pem && (systemctl reload haproxy || true)"
  action [:install, :run]
end

haproxy_install 'package'

haproxy_config_global '' do
  chroot '/var/lib/haproxy'
end

haproxy_config_defaults 'defaults' do
  mode 'http'
  haproxy_retries 3
end

haproxy_frontend 'http-in' do
  mode 'http'
  bind '*:80'
  extra_options redirect: 'scheme https code 301 if !{ ssl_fc }'
end

haproxy_frontend 'https' do
  mode 'http'
  bind '*:443 ssl crt /etc/ssl/private/fullchain.pem'
  default_backend 'upstream'
end

haproxy_backend 'upstream' do
  server ['server1 127.0.0.1:8000 maxconn 32']
end

haproxy_service 'haproxy' do
  action [:create, :enable, :start]
end
