require 'spec_helper'

describe 'letsencrypt::certonly' do
  on_supported_os.each do |os, facts|
    let :facts do
      facts
    end

    context "on #{os} based operating systems" do
      puts "we are on facter version #{facts[:facterversion]}"
      puts "operatingsystemrelease is #{facts[:operatingsystemrelease]} and operatingsystem is #{facts[:operatingsystem]}"
      let(:pre_condition) { "class { letsencrypt: email => 'foo@example.com', package_command => 'letsencrypt' }" }

      context 'with a single domain' do
        let(:title) { 'foo.example.com' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('Letsencrypt::Install') }
        it { is_expected.to contain_class('Letsencrypt::Config') }
        it { is_expected.to contain_class('Letsencrypt::Params') }
        it { is_expected.to contain_file('/etc/letsencrypt') }
        # it { is_expected.to contain_package('letsencrypt') }
        it { is_expected.to contain_ini_setting('/etc/letsencrypt/cli.ini email foo@example.com') }
        it { is_expected.to contain_ini_setting('/etc/letsencrypt/cli.ini server https://acme-v01.api.letsencrypt.org/directory') }
        it { is_expected.to contain_exec('initialize letsencrypt') }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com') }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_onlyif "test -f /etc/letsencrypt/live/foo.example.com/cert.pem && ( openssl x509 -in /etc/letsencrypt/live/foo.example.com/cert.pem -text -noout | grep -oE 'DNS:[^ ,]*' | sed 's/^DNS://g;'; echo 'foo.example.com' | tr ' ' '\\n') | sort | uniq -c | grep -qv '^[ \t]*2[ \t]'" }
      end

      context 'with multiple domains' do
        let(:title) { 'foo' }
        let(:params) { { domains: ['foo.example.com', 'bar.example.com', '*.example.com'] } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --cert-name foo -d foo.example.com -d bar.example.com -d *.example.com' }
      end

      context 'with custom command' do
        let(:title) { 'foo.example.com' }
        let(:params) { { letsencrypt_command: '/usr/lib/letsencrypt/letsencrypt-auto' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_command '/usr/lib/letsencrypt/letsencrypt-auto --text --agree-tos --non-interactive certonly -a standalone --cert-name foo.example.com -d foo.example.com' }
      end

      context 'with webroot plugin' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          { plugin: 'webroot',
            webroot_paths: ['/var/www/foo'] }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a webroot --cert-name foo.example.com --webroot-path /var/www/foo -d foo.example.com' }
      end

      context 'with webroot plugin and multiple domains' do
        let(:title) { 'foo' }
        let(:params) do
          { domains: ['foo.example.com', 'bar.example.com'],
            plugin: 'webroot',
            webroot_paths: ['/var/www/foo', '/var/www/bar'] }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a webroot --cert-name foo --webroot-path /var/www/foo -d foo.example.com --webroot-path /var/www/bar -d bar.example.com' }
      end

      context 'with webroot plugin, one webroot, and multiple domains' do
        let(:title) { 'foo' }
        let(:params) do
          { domains: ['foo.example.com', 'bar.example.com'],
            plugin: 'webroot',
            webroot_paths: ['/var/www/foo'] }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a webroot --cert-name foo --webroot-path /var/www/foo -d foo.example.com -d bar.example.com' }
      end

      context 'with webroot plugin and no webroot_paths' do
        let(:title) { 'foo.example.com' }
        let(:params) { { plugin: 'webroot' } }

        it { is_expected.not_to compile.with_all_deps }
        it { is_expected.to raise_error Puppet::Error, %r{'webroot_paths' parameter must be specified} }
      end

      context 'with custom plugin' do
        let(:title) { 'foo.example.com' }
        let(:params) { { plugin: 'apache' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a apache --cert-name foo.example.com -d foo.example.com' }
      end

      context 'with custom plugin and manage_cron' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            plugin: 'apache',
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_command '"/var/lib/puppet/letsencrypt/renew-foo.example.com.sh"' }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a apache --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage_cron and defined cron_hour (integer)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_hour: 13,
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_hour 13 }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage_cron and out of range defined cron_hour (integer)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_hour: 24,
            manage_cron: true
          }
        end

        it { is_expected.not_to compile.with_all_deps }
        it { is_expected.to raise_error Puppet::Error }
      end

      context 'with manage_cron and defined cron_hour (string)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_hour: '00',
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_hour '00' }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage_cron and defined cron_hour (array)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_hour: [1, 13],
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_hour [1, 13] }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage_cron and defined cron_minute (integer)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_minute: 15,
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_minute 15 }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage_cron and out of range defined cron_hour (integer)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_hour: 66,
            manage_cron: true
          }
        end

        it { is_expected.not_to compile.with_all_deps }
        it { is_expected.to raise_error Puppet::Error }
      end

      context 'with manage_cron and defined cron_minute (string)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_minute: '15',
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_minute '15' }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage_cron and defined cron_minute (array)' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            cron_minute: [0, 30],
            manage_cron: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_minute [0, 30] }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with custom puppet_vardir path and manage_cron' do
        let :facts do
          super().merge(puppet_vardir: '/tmp/custom_vardir')
        end
        let(:title) { 'foo.example.com' }
        let(:params) do
          { plugin: 'apache',
            manage_cron: true }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/tmp/custom_vardir/letsencrypt').with_ensure('directory') }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_command '"/tmp/custom_vardir/letsencrypt/renew-foo.example.com.sh"' }
        it { is_expected.to contain_file('/tmp/custom_vardir/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a apache --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with custom plugin and manage cron and cron_success_command' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          {
            plugin: 'apache',
            manage_cron: true,
            cron_before_command: 'echo before',
            cron_success_command: 'echo success'
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_command '"/var/lib/puppet/letsencrypt/renew-foo.example.com.sh"' }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n(echo before) && /opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a apache --keep-until-expiring --cert-name foo.example.com -d foo.example.com && (echo success)\n" }
      end

      context 'without plugin' do
        let(:title) { 'foo.example.com' }
        let(:params) { { custom_plugin: true } }

        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly --cert-name foo.example.com -d foo.example.com' }
      end

      context 'with invalid plugin' do
        let(:title) { 'foo.example.com' }
        let(:params) { { plugin: 'bad' } }

        it { is_expected.not_to compile.with_all_deps }
        it { is_expected.to raise_error Puppet::Error }
      end

      context 'when specifying additional arguments' do
        let(:title) { 'foo.example.com' }
        let(:params) { { additional_args: ['--foo bar', '--baz quux'] } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_command '/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --cert-name foo.example.com -d foo.example.com --foo bar --baz quux' }
      end

      describe 'when specifying custom environment variables' do
        let(:title) { 'foo.example.com' }
        let(:params) { { environment: ['FOO=bar', 'FIZZ=buzz'] } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_environment(['VENV_PATH=/opt/letsencrypt/.venv', 'FOO=bar', 'FIZZ=buzz']) }
      end

      context 'with custom environment variables and manage_cron' do
        let(:title) { 'foo.example.com' }
        let(:params) { { environment: ['FOO=bar', 'FIZZ=buzz'], manage_cron: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\nexport FOO=bar\nexport FIZZ=buzz\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with manage cron and suppress_cron_output' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          { manage_cron: true,
            suppress_cron_output: true }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with_command '"/var/lib/puppet/letsencrypt/renew-foo.example.com.sh"' }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com > /dev/null 2>&1\n" }
      end

      context 'with manage cron and custom day of month' do
        let(:title) { 'foo.example.com' }
        let(:params) do
          { manage_cron: true,
            cron_monthday: [1, 15] }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_cron('letsencrypt renew cron foo.example.com').with(monthday: [1, 15]) }
        it { is_expected.to contain_file('/var/lib/puppet/letsencrypt/renew-foo.example.com.sh').with_content "#!/bin/sh\nexport VENV_PATH=/opt/letsencrypt/.venv\n/opt/letsencrypt/.venv/bin/letsencrypt --text --agree-tos --non-interactive certonly -a standalone --keep-until-expiring --cert-name foo.example.com -d foo.example.com\n" }
      end

      context 'with custom config_dir' do
        let(:title) { 'foo.example.com' }
        let(:pre_condition) { "class { letsencrypt: email => 'foo@example.com', config_dir => '/foo/bar/baz', package_command => 'letsencrypt'}" }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/foo/bar/baz').with_ensure('directory') }
        it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_onlyif "test -f /foo/bar/baz/live/foo.example.com/cert.pem && ( openssl x509 -in /foo/bar/baz/live/foo.example.com/cert.pem -text -noout | grep -oE 'DNS:[^ ,]*' | sed 's/^DNS://g;'; echo 'foo.example.com' | tr ' ' '\\n') | sort | uniq -c | grep -qv '^[ \t]*2[ \t]'" }
      end
    end
  end

  context 'on FreeBSD' do
    let(:title) { 'foo.example.com' }
    let(:facts) { { osfamily: 'FreeBSD', operatingsystem: 'FreeBSD', operatingsystemrelease: '10.3-RELEASE-p7', operatingsystemmajrelease: '10', path: '/usr/bin' } }
    let(:pre_condition) { "class { letsencrypt: email => 'foo@example.com'}" }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_command %r{^certbot} }
    it { is_expected.to contain_ini_setting('/usr/local/etc/letsencrypt/cli.ini email foo@example.com') }
    it { is_expected.to contain_ini_setting('/usr/local/etc/letsencrypt/cli.ini server https://acme-v01.api.letsencrypt.org/directory') }
    it { is_expected.to contain_file('/usr/local/etc/letsencrypt').with_ensure('directory') }
    it { is_expected.to contain_exec('letsencrypt certonly foo.example.com').with_onlyif "test -f /usr/local/etc/letsencrypt/live/foo.example.com/cert.pem && ( openssl x509 -in /usr/local/etc/letsencrypt/live/foo.example.com/cert.pem -text -noout | grep -oE 'DNS:[^ ,]*' | sed 's/^DNS://g;'; echo 'foo.example.com' | tr ' ' '\\n') | sort | uniq -c | grep -qv '^[ \t]*2[ \t]'" }
  end
end
