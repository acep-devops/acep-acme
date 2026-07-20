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
  cmd = %w(certbot certonly)
  cmd.append certbot_opts(new_resource)

  # Ensure the requests library trusts a custom CA if specified
  cmd_env = {}
  if property_is_set?(:trusted_ca_bundle)
    cmd_env['REQUESTS_CA_BUNDLE'] = new_resource.trusted_ca_bundle
  end

  # This is so we can ensure we run at the end of the run
  # Otherwise we can run into issues when running with cookbooks that use the accumulator pattern
  # like the HAProxy cookbook.
  with_run_context(:root) do
    execute "Generate Certbot certificate for #{new_resource.domains.first}" do
      command cmd.join(' ')
      environment cmd_env
      retries 1
      retry_delay 30
      action :nothing
    end.delayed_action(:run)
  end
end

action :install do
  package 'certbot'
end

action_class do
  include AcepAcme::CertbotHelpers
end
