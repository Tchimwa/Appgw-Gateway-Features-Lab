#!/bin/bash
# Script to deploy a very simple web application.
# Here we'll have a simple HTTPS and HTTPS web page built on NGINX

echo "==="
echo "Installing NGINX web server ..."
echo "==="

#Installing NGINX
sudo apt-get -y update
sudo apt-get install nginx openssl -y

#Enablin the fw and opening the necessary ports
sudo ufw allow "OpenSSH"
sudo ufw allow "Nginx HTTP"
sudo ufw allow "Nginx HTTPS"
sudo ufw allow "Nginx full"
sudo ufw enable

#Downloading  the certificate from my storage account
sudo mkdir -p /etc/nginx/certificate
sudo chmod -R 777 /etc/nginx/certificate
cd /etc/nginx/certificate
curl -k https://data.ced-sougang.com/media/wildcard_ced-sougang_com.crt --output wildcard_ced-sougang_com.crt
curl -k https://data.ced-sougang.com/media/wildcard_ced-sougang_com.key --output wildcard_ced-sougang_com.key
curl -k https://data.ced-sougang.com/media/wildcard_ced-sougang_com.pem --output wildcard_ced-sougang_com.pem

#setting up different web pages
sudo mkdir -p /var/www/w3/html
sudo mkdir -p /var/www/netdata/html
sudo mkdir -p /var/www/labtime/html

sudo touch /etc/nginx/sites-available/ced-sougang.com.conf
sudo touch /etc/nginx/sites-available/netdata.ced-sougang.com.conf
sudo touch /etc/nginx/sites-available/labtime.ced-sougang.com.conf

sudo su -
cat << EOM > /var/www/w3/html/index.html
<html>
  <head><title>Networking DU</title></head>
  <body>
  <div style="width:800px; margin: 0 auto">
  <!-- BEGIN -->
    <center><h2>Fellow Network Engineers </h2></center>
  <center>Welcome to the LABTIME Session 3!</center>
  <center><h2> This is <font color="blue">www.ced-sougang.com! </font></h2></center>
  <center><h2>from Tchimwa!</h2></center>
  <!-- END -->
    </div>
  </body>
</html>
EOM

cat << EOM > /var/www/netdata/html/index.html
<html>
  <head><title>Networking DU</title></head>
  <body>
  <div style="width:800px; margin: 0 auto">
  <!-- BEGIN -->
    <center><h2>Fellow Network Engineers </h2></center>
  <center>Welcome to the LABTIME Session 3!</center>
  <center><h2> This is <font color="blue">netdata.ced-sougang.com! </font></h2></center>
  <center><h2>from Tchimwa!</h2></center>
  <!-- END -->
    </div>
  </body>
</html>
EOM

cat << EOM >  /var/www/labtime/html/index.html
<html>
  <head><title>Networking DU</title></head>
  <body>
  <div style="width:800px; margin: 0 auto">
  <!-- BEGIN -->
    <center><h2>Fellow Network Engineers </h2></center>
  <center>Welcome to the LABTIME Session 3!</center>
  <center><h2> This is <font color="blue">labtime.ced-sougang.com! </font></h2></center>
  <center><h2>from Tchimwa!</h2></center>
  <!-- END -->
    </div>
  </body>
</html>
EOM

cat << EOM >  /etc/nginx/sites-available/www.ced-sougang.com.conf
server {
        listen 80;
        listen [::]:80;
        server_name www.ced-sougang.com;
        root  /var/www/w3/html;
        index index.html;
        location / {
            try_files $uri $uri/ =404;
        }
}
server {
        listen 443 ssl;
        listen [::]:443 ssl;
        ssl_certificate /etc/nginx/certificate/wildcard_ced-sougang_com.pem;
        ssl_certificate_key /etc/nginx/certificate/wildcard_ced-sougang_com.key;
        root /var/www/w3/html;
        index index.html;
        server_name www.ced-sougang.com;
        location / {
                try_files $uri $uri/ =404;
        }
}
EOM

cat << EOM >  /etc/nginx/sites-available/netdata.ced-sougang.com.conf
server {
        listen 80;
        listen [::]:80;
        server_name netdata.ced-sougang.com;
        root  /var/www/netdata/html;
        index index.html;
        location / {
            try_files $uri $uri/ =404;
        }
}
server {
        listen 443 ssl;
        listen [::]:443 ssl;
        ssl_certificate /etc/nginx/certificate/wildcard_ced-sougang_com.pem;
        ssl_certificate_key /etc/nginx/certificate/wildcard_ced-sougang_com.key;
        root /var/www/netdata/html;
        index index.html;
        server_name netdata.ced-sougang.com;
        location / {
                try_files $uri $uri/ =404;
        }
}
EOM

cat << EOM >  /etc/nginx/sites-available/labtime.ced-sougang.com.conf
server {
        listen 80;
        listen [::]:80;
        server_name labtime.ced-sougang.com;
        root  /var/www/labtime/html;
        index index.html;
        location / {
            try_files $uri $uri/ =404;
        }
}
server {
        listen 443 ssl;
        listen [::]:443 ssl;
        ssl_certificate /etc/nginx/certificate/wildcard_ced-sougang_com.pem;
        ssl_certificate_key /etc/nginx/certificate/wildcard_ced-sougang_com.key;
        root /var/www/labtime/html;
        index index.html;
        server_name labtime.ced-sougang.com;
        location / {
                try_files $uri $uri/ =404;
        }
}
EOM

#Enabling the websites
ln -s /etc/nginx/sites-available/labtime.ced-sougang.com.conf /etc/nginx/sites-enabled/labtime.ced-sougang.com.conf
ln -s /etc/nginx/sites-available/netdata.ced-sougang.com.conf /etc/nginx/sites-enabled/netdata.ced-sougang.com.conf
ln -s /etc/nginx/sites-available/ced-sougang.com.conf /etc/nginx/sites-enabled/ced-sougang.com.conf

#Setting the hosts file for DNS resolution
#ip=$(echo `ifconfig eth0 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://'`)
echo "127.0.0.1 www.ced-sougang.com" | tee -a /etc/hosts
echo "127.0.0.1 netdata.ced-sougang.com" | tee -a /etc/hosts
echo "127.0.0.1 labtime.ced-sougang.com" | tee -a /etc/hosts

#Restarting NGINX to apply the configuration
systemctl restart nginx