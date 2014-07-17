#!/bin/bash

sudo apt-get install -y --force-yes vim curl
rm /etc/nginx/nginx.conf
test -f /etc/nginx/nginx.conf || sudo ln -s /home/vagrant/redx/nginx.conf /etc/nginx/nginx.conf
sudo /bin/kill -HUP $(cat /run/nginx.pid) # reload nginx
