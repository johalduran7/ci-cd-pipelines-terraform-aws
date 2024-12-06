FROM jenkins/jenkins:lts

USER root
# install dependencies
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install sudo -y 
RUN apt-get install inetutils-ping -y
RUN apt-get install openssh-client -y
RUN apt-get install openssh-server -y
RUN apt-get install -y vim
RUN apt-get install net-tools -y
RUN apt-get install python3 -y
RUN apt-get install git -y
RUN apt-get install default-jdk -y

RUN apt-get install jq -y
RUN apt-get install -y libaio1 wget unzip 
RUN	apt-get clean
RUN apt-get install bc -y
RUN apt-get install telnet -y
RUN apt-get install ufw -y
# disable ipv6 not to have issues with ufw
RUN sed  -i 's/ipv6=yes/ipv6=no/g' /etc/default/ufw 
RUN echo 'root:1234' | chpasswd
RUN mkdir /run/sshd
RUN sed  -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
RUN ssh-keygen -t rsa -b 4096 -f ~/.ssh/ubuntu-agent1 -N "holahola"
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDW72PZqHQR4Hfzv2NJyyaAFiO0lxGg3gANa/1tM3FY528odI0/XWJ1Ll0sYMfgoAWBJuj7sSorxbKZQkByjAYoJcESIWaWioTnBOvq6cnw0Lulsl4UySJalCDC3ndpa41I020pCKUIiBFP1km6P2F2a17DHPO5tghp0sg8Bi+awS7f8FBakT/8aVW7ln86KeB6qKTUnWFOxDJObCfMa6ZkZulAhX+Ax23DEhne0/h4hN44amVDQ7t7bjXsXZTLPuH3ZQGfT5+wZS2SWT9dg2AMUnv+EBuEA1CEw6x/GzBdHQCwl5on1a6/shy47yWgI3EoNgVoQeIcgVcpQ0eYYPnT6ZaTTdrWw6/3tawbnmAcbwvUycFdQu7nrKsIXQXd4ON6lgS5gaTlFhQYmhhcToRVRO4Ixj+8uhe5lr2T5kvEKOllqc5bGXVD/v5pXKizCLEBXk788gPQM6hTxWKw4UgUJ/i7VeIup+AEsYgR9gOLwXsol0y6yh5l2iYk5IoVjLBhbaZsScqGcgPZ+lK9HORYB+BHb4NTVZbd8tIGiryZcNhcVPlsJiZWvd4XGo0UBz5ezecqw1F70Aji+0oqT41YdWO8kBtCqg3c+k2s/UU0sauEJOXvzoqN0CdkkSGf7wMCDLBiHXHOn4NAc3EkpCnzKW5T26eagYrx2eKMzUw0xw== jenkins@c506c16ef513" >> ~/.ssh/authorized_keys
EXPOSE 22 2376
#RUN sudo ufw enable
#RUN ufw allow 8080/tcp
#RUN ufw allow 2376/tcp
#RUN ufw allow 50000/tcp
USER jenkins
CMD ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]