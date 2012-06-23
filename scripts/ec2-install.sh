sudo groupadd keg_io
sudo useradd --shell /bin/bash --create-home --gid keg_io --groups wheel keg_io
sudo passwd -f -u keg_io

sudo yum update
sudo yum groupinstall "Development Tools"
sudo yum install -y openssl-devel

sudo yum localinstall -y  --nogpgcheck http://nodejs.tchol.org/repocfg/amzn1/nodejs-stable-release.noarch.rpm
sudo yum install -y nodejs-compat-symlinks npm
# wget http://nodejs.org/dist/v0.6.11/node-v0.6.11.tar.gz
# tar xvfz node-v0.6.11.tar.gz
# cd node-v0.6.11
# ./configure
# make
# sudo make install

# sudo export PATH=$PATH:/usr/local/bin
sudo npm install -g coffee-script

echo '[10gen]' >> 10gen.repo
echo 'name=10gen Repository' >> 10gen.repo
echo 'baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64' >> 10gen.repo
echo 'gpgcheck=0' >> 10gen.repo
echo 'enabled=1' >> 10gen.repo

sudo mv 10gen.repo /etc/yum.repos.d
sudo yum update
sudo yum install -y mongo-10gen mongo-10gen-server
sudo mkdir -p /data/db
sudo service mongod start

sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8888
sudo /sbin/service iptables save

su - keg_io
cd
ssh-keygen -t rsa
git clone git@github.com:dcarney/keg.io.git
npm install

