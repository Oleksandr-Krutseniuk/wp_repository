#!/bin/bash

Create mount volume for logs
sudo mkfs.ext4 /dev/sdf
sudo mkdir /var/log
sudo mount -t ext4 /dev/sdf /var/log

Install & Start nginx server
sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

Print the hostname which includes instance details on nginx homepage
sudo sh -c "echo 'Hello from $(hostname -f)' > /var/www/html/index.html"