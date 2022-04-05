#!/bin/bash
# Script to deploy a very simple web application.
# The web app has a customizable image and some text.
echo "==="
echo "Installing Apache2 web server ..."
echo "==="
apt -y update
apt -y install apache2
systemctl start apache2
systemctl enable apache2

cat << EOM > /var/www/html/index.html
<html>
  <head><title>Networking DU</title></head>
  <body>
  <div style="width:800px;margin: 0 auto">
  <!-- BEGIN -->
    <center><h2>Fellow Network Engineers </h2></center>
  <center>Welcome to the LABTIME Session 3!</center>
  <center><h2>=^._.^= </h2></center>
  <center><h2>$hostname</h2></center>


  <!-- END -->
    </div>
  </body>
</html>
EOM

echo "==="
echo "Installation complete."
echo "==="
