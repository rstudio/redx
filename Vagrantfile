# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = 'chef/ubuntu-12.04'

  config.vm.hostname = 'redx'

  config.vm.network :forwarded_port, guest: 8080, host: 8080
  config.vm.network :forwarded_port, guest: 8081, host: 8081
  config.vm.network :forwarded_port, guest: 6379, host: 6379

  # install the latest version of chef
  config.omnibus.chef_version = :latest

  # enable berkshelf
  config.berkshelf.enabled = true

  # run chef-solo
  config.vm.provision :chef_solo do |chef|

    chef.json = {
      "redx" => {
        "dir" => "/home/vagrant/redx",
        "nginx" => {
          "api_ports" => [8081],
          "main_ports" => [8080]
        }
      },
      "redis" => {
        "install_type" => "source",
        "config" => {
          "save" => []
        }
      }
    }

    chef.add_recipe "apt"
    chef.add_recipe "redis::server"
    chef.add_recipe "redx"
  end

  config.vm.provision :shell, :path => 'post-install.sh'

  ### Configure Providers ###
  config.vm.provider 'virtualbox' do |provider, override|
    provider.customize ['modifyvm', :id, '--memory', '1024']
    override.vm.synced_folder '.', '/home/vagrant/redx/'
  end

end
