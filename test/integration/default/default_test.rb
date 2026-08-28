# Chef InSpec test for recipe acep-acme::default

# The Chef InSpec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec/resources/

describe file('/etc/ssl/private/test.local.pem') do
  it { should exist }
end

describe port(443) do
  it { should be_listening }
end

describe port(80) do
  it { should be_listening }
end

describe x509_certificate('/etc/ssl/private/test.local.pem') do
  it { should be_valid }
  its('subject_alt_names') { should include 'DNS:test.local' }
  its('subject_alt_names') { should include 'DNS:secondary-test.local' }
end