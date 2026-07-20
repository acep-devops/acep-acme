# acep-acme

This Chef cookbook provides a custom resource, `certbot`, to automate obtaining and renewing SSL/TLS certificates via ACME servers (such as Let's Encrypt or private ACME environments) using the Certbot client.

---

## Requirements

### Platforms
- Ubuntu/Debian
- Any other Linux distribution supporting `certbot` package installation

### Chef
- Chef Infra Client 18+ (or any version supporting unified mode custom resources)

---

## Resources

### certbot

The `certbot` custom resource manages package installation and certificates generation.

#### Actions

- `:install` - Installs the certbot package.
- `:run` (*default*) - Generates or renews the requested certificate.

#### Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `domains` | `String` or `Array` | *Name Property* | The domain name(s) to obtain a certificate for. If multiple domains are provided, they will be specified with `-d` flags, and the first domain will default as the `cert_name`. |
| `cert_name` | `String` | `nil` | The specific name of the certificate. Defaults to the first domain in `domains`. |
| `email` | `String` | *Required* | Email address used for registration, recovery contact, and key-loss notifications. |
| `acme_endpoint` | `String` | `'http://acme-v02.api.letsencrypt.org/directory'` | The ACME server directory endpoint. |
| `authenticator` | `String` | `'standalone'` | The Certbot authenticator plugin to use. Common choices include `standalone` or `webroot`. |
| `webroot_path` | `String` | `nil` | The public directory of your web server. Required when `authenticator` is set to `'webroot'`. |
| `http_01_port` | `Integer` | `80` | Port used during the HTTP-01 challenge when running the `standalone` authenticator. |
| `trusted_ca_bundle` | `String` | `nil` | Local path to a custom CA bundle (sets `REQUESTS_CA_BUNDLE` environment variable). Highly useful when using internal or private ACME directory servers. |
| `pre_hook` | `String` | `nil` | Command to run in a shell before attempting to obtain/renew certificates. |
| `post_hook` | `String` | `nil` | Command to run in a shell after attempting to obtain/renew certificates. |
| `deploy_hook` | `String` | `nil` | Command to run in a shell only when a certificate is successfully obtained or renewed. |
| `extra_args` | `Array` | `[]` | Extra command-line arguments passed directly to the `certbot certonly` command. |

---

## Examples

### 1. Simple Standalone Certificate
To run a standalone challenge for a single domain:

```ruby
certbot 'example.com' do
  email 'admin@example.com'
  action [:install, :run]
end
```

### 2. Multi-domain Certificate with Standalone Authenticator

```ruby
certbot 'my_app_certs' do
  domains ['example.com', 'www.example.com', 'api.example.com']
  email 'admin@example.com'
  http_01_port 8080
  action :run
end
```

### 3. Using Webroot Authenticator (e.g., with Nginx or Apache)
Specify a `webroot_path` to verify the ACME challenge without shutting down or interfering with your existing web server:

```ruby
certbot 'example.com' do
  email 'admin@example.com'
  authenticator 'webroot'
  webroot_path '/var/www/html'
  action :run
end
```

### 4. Custom ACME Server with Pre/Post and Deploy Hooks
Obtain a certificate from an internal/private ACME server (like HashiCorp Vault or Smallstep) with a custom CA bundle and reload services on successful deployment:

```ruby
certbot 'internal.example.local' do
  email 'sysadmin@example.local'
  acme_endpoint 'https://ca.example.local/acme/acme/directory'
  trusted_ca_bundle '/usr/local/share/ca-certificates/internal-ca.crt'
  pre_hook 'systemctl stop nginx'
  post_hook 'systemctl start nginx'
  deploy_hook 'systemctl reload postfix'
  action :run
end
```
