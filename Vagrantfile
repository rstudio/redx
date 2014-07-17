# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = 'hashicorp/precise64'

  config.vm.hostname = 'redx'

  config.vm.network :forwarded_port, guest: 6379, host: 6379

  # install the latest version of chef
  config.omnibus.chef_version = :latest

  # enable berkshelf
  config.berkshelf.enabled = true

  # run chef-solo
  config.vm.provision :chef_solo do |chef|

    chef.json = {
      "redis" => {
        "install_type" => "source",
        "config" => {
          "save" => []
        }
      }
    }

    chef.add_recipe "git"
    chef.add_recipe "openresty"
    chef.add_recipe "openresty::luarocks"
    chef.add_recipe "redis::server"
  end

  config.vm.provision :shell, :path => 'post-install.sh'

  ### Configure Providers ###
  config.vm.provider 'virtualbox' do |provider, override|
    provider.customize ['modifyvm', :id, '--memory', '1024']
    override.vm.synced_folder '.', '/home/vagrant/redx/'
  end

end
