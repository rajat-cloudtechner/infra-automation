#!/bin/bash

sudo yum update -y
sudo yum search docker
sudo yum install docker -y
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -a -G docker ec2-user
sudo chmod 666 /var/run/docker.sock
