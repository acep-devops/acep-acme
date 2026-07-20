#
# Chef Infra Documentation
# https://docs.chef.io/libraries/
#

#
# This module name was auto-generated from the cookbook name. This name is a
# single word that starts with a capital letter and then continues to use
# camel-casing throughout the remainder of the name.
#
module AcepAcme
  module CertbotHelpers
    #
    # Define the methods that you would like to assist the work you do in recipes,
    # resources, or templates.
    #
    # def my_helper_method
    #   # help method implementation
    # end
    def certbot_opts
      opts = [
        '--non-interactive',
        '--agree-tos',
        '--keep-until-expiring',
        "--email #{new_resource.email}",
        "--authenticator #{new_resource.authenticator}",
      ]

      opts << if new_resource.cert_name
                "--cert-name #{new_resource.cert_name}"
              else
                "--cert-name #{new_resource.domains.first}"
              end

      if new_resource.http_01_port
        opts << '--preferred-challenges http-01'
        opts << "--http-01-port #{new_resource.http_01_port}"
      end

      new_resource.domains.each do |domain|
        opts << "-d #{domain}"
      end

      # Append webroot path if using webroot authenticator
      if new_resource.authenticator == 'webroot'
        raise 'webroot_path property is required when using webroot authenticator' unless new_resource.webroot_path
        opts << "-w #{new_resource.webroot_path}"
      end

      opts << "--pre-hook '#{new_resource.pre_hook}'" if new_resource.pre_hook
      opts << "--post-hook '#{new_resource.post_hook}'" if new_resource.post_hook
      opts << "--deploy-hook '#{new_resource.deploy_hook}'" if new_resource.deploy_hook

      # Specify the custom ACME server
      opts << "--server #{new_resource.acme_endpoint}"

      # Append any additional arguments provided
      opts += new_resource.extra_args unless new_resource.extra_args.empty?

      opts
    end
  end
end
