#!/bin/bash

sudo yum update
sudo yum search docker
sudo yum install docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
