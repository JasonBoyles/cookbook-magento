define :fpm_allow do

  php_conf =  if platform?('centos', 'redhat')
                ["/etc", "/etc/php.d"]
              else
                ["/etc/php5/fpm", "/etc/php5/conf.d"]
              end
  
  if node['php-fpm']['slaves'].empty?
  	permit = ",#{node['php-fpm']['master']}"
  else
    permit = ",#{node['php-fpm']['master']},#{node['php-fpm']['slaves'].join(",")}"
  end

  node['php-fpm']['pools'].each do |pool|
    bash "Permit slave nodes of #{pool} to leverage this PHP-FPM setup" do
      cwd "#{php_conf[0]}/pools/" # php.ini location
      code <<-EOH
      sed -i 's/listen.allowed_clients = .*/listen.allowed_clients = 127.0.0.1#{permit}/' #{pool}.conf
      EOH
      notifies :restart, resources(:service => "php-fpm")
    end
  end

  # S192.237.183.249etup firewall rules
  fpm_port = node['php-fpm']['pool']['magento']['listen'].split(":")[1].to_i

  case node["platform_family"]
  when "rhel", "fedora"
    fwfile = "/etc/sysconfig/iptables"

    node['php-fpm']['slaves'].each do |ip|
      rule = "-I INPUT -s #{ip} -p tcp -m tcp --dport #{fpm_port} -j ACCEPT"
      execute "Adding iptables rule for #{port}" do
        command "iptables #{rule}"
        not_if "grep \"\\#{rule}\" #{fwfile}"
      end
    end
    # Save iptables rules
    execute "Saving fpm iptables rule set" do
      command "/sbin/service iptables save"
    end
  else
    include_recipe "firewall"

    node['php-fpm']['slaves'].each do |ip|
      firewall_rule "fpm-#{fpm_port}" do
        port fpm_port
        source ip
        interface eth1
        action :allow
      end
    end
  end
end