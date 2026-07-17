# To learn more about Custom Resources, see https://docs.chef.io/custom_resources/
resource_name :certbot
provides :certbot
unified_mode true

property :domains, [String, Array], name_property: true, coerce: proc { |x| [x].flatten }
property :cert_name, String
property :email, String, required: true
property :acme_endpoint, String, default: 'http://acme-v02.api.letsencrypt.org/directory'
property :authenticator, String, default: 'standalone'
property :webroot_path, String # Needed for webroot authenticator
property :http_01_port, Integer, default: 80
property :trusted_ca_bundle, String # Path to local CA cert if using a private ACME server
property :pre_hook, String
property :post_hook, String
property :deploy_hook, String
property :extra_args, Array, default: []

action :run do
  # Build the certbot CLI command
  cmd = [
    'certbot', 'certonly',
    '--non-interactive',
    '--agree-tos',
    '--keep-until-expiring',
    "--email #{new_resource.email}",
    "--authenticator #{new_resource.authenticator}"
  ]

  if new_resource.cert_name
    cmd << "--cert-name #{new_resource.cert_name}"
  else
    cmd << "--cert-name #{new_resource.domains.first}"
  end

  new_resource.domains.each do |domain|
    cmd << "-d #{domain}"
  end

  # Append webroot path if using webroot authenticator
  if new_resource.authenticator == 'webroot'
    raise 'webroot_path property is required when using webroot authenticator' unless new_resource.webroot_path
    cmd << "-w #{new_resource.webroot_path}"
  end

  cmd << "--pre-hook '#{new_resource.pre_hook}'" if new_resource.pre_hook
  cmd << "--post-hook '#{new_resource.post_hook}'" if new_resource.post_hook
  cmd << "--deploy-hook '#{new_resource.deploy_hook}'" if new_resource.deploy_hook

  # Specify the custom ACME server
  cmd << "--server #{new_resource.acme_endpoint}"

  # Append any additional arguments provided
  cmd += new_resource.extra_args unless new_resource.extra_args.empty?

  # Ensure the requests library trusts a custom CA if specified
  cmd_env = {}
  if new_resource.trusted_ca_bundle
    cmd_env['REQUESTS_CA_BUNDLE'] = new_resource.trusted_ca_bundle
  end

  execute "Generate Certbot certificate for #{new_resource.domains.first}" do
    command cmd.join(' ')
    environment cmd_env
    action :run
  end
end

action :install do
  package 'certbot'
end
