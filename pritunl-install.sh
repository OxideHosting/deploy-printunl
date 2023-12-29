preflight(){
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
    dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
    dist_version=$(cut -d "." -f1 <<< ${dist_version})
  else
    exit 1
  fi
  if [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ] || [ "$lsb_dist" = "fedora" ]; then
    if ! [ "$lsb_dist" = "fedora" ]; then
      lsb_dist="redhat"
    fi
    dist_version="8"
  elif [ "$lsb_dist" = "ubuntu" ] || [ "$lsb_dist" = "debian" ]; then
      if [ "$dist_version" = "22" ]; then
        echo "Ubuntu 22.04 is not currently supported by Pritunl, exiting..."
        exit 2
      elif [ "$dist_version" = "11" ]; then
        echo "Debian 11 is not currently supported by Pritunl, exiting..."
        exit 2
      fi
  fi
}

install(){
  if [ "$lsb_dist" = "ubuntu" ] || [ "$lsb_dist" = "debian" ]; then
    apt-get update
    apt-get install -y sudo gnupg dnsutils
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    if [ "$lsb_dist" = "ubuntu" ]; then
      echo "deb [ trusted=yes arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $codename/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    else
      echo "deb [ trusted=yes arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian $codename/mongodb-org/6.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    fi
    echo "deb [ trusted=yes ] https://repo.pritunl.com/stable/apt $codename main" | sudo -E tee /etc/apt/sources.list.d/pritunl.list >/dev/null 2>&1
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
    sudo systemctl stop ufw.service nginx.service httpd.service apache.service
    sudo systemctl disable ufw.service nginx.service httpd.service apache.service
    sudo apt-get --assume-yes install apt-transport-https
    sudo sh -c "echo 'deb [ trusted=yes ] https://deb.debian.org/debian buster-backports main contrib non-free' > /etc/apt/sources.list.d/buster-backports.list"
    sudo apt-get update -y
    sudo apt-get install -y mongodb-org pritunl wireguard
  elif [ "$lsb_dist" = "redhat" ] || [ "$lsb_dist" = "fedora" ]; then
    dnf update -y
    dnf install -y sudo bind-utils
echo "[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc" | sudo -E tee /etc/yum.repos.d/mongodb-org-6.0.repo >/dev/null 2>&1
echo '[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/oraclelinux/8/
gpgcheck=1
enabled=1' | sudo -E tee /etc/yum.repos.d/pritunl.repo >/dev/null 2>&1
    if [ "$lsb_dist" = "redhat" ]; then
      sudo rpm -Uvh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$dist_version.noarch.rpm"
    fi
    gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A
    gpg --armor --export 7568D9BB55FF9E5287D586017AE645C0CF8E292A > key.tmp; sudo rpm --import key.tmp; rm -f key.tmp
    sudo dnf -y remove iptables-services
    sudo systemctl stop ufw.service nginx.service httpd.service apache.service
    sudo systemctl disable ufw.service nginx.service httpd.service apache.service
    if [ "$lsb_dist" = "centos" ]; then
      sudo dnf install -y elrepo-release epel-release
      sudo dnf install -y mongodb-org pritunl kmod-wireguard wireguard-tools
    else
      sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
      sudo dnf install -y mongodb-org pritunl kmod-wireguard wireguard-tools
    fi
  fi
  systemctl enable --now pritunl mongod
  server_ip=$(curl -s http://checkip.amazonaws.com)
  domain_record=$(dig +short "${HOSTNAME}")
  if [ "${server_ip}" = "${domain_record}" ]; then
    echo "You can access the Pritunl panel using the following link - https://$HOSTNAME"
  else
    echo "You can access the Pritunl panel using the following link - https://$server_ip"
  fi
}

preflight
install
