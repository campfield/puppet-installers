#!/bin/bash

sudo apt-get update

sudo DEBIAN_FRONTEND='noninteractive' apt-get -y install software-properties-common

sudo DEBIAN_FRONTEND='noninteractive' add-apt-repository -y ppa:apptainer/ppa

sudo DEBIAN_FRONTEND='noninteractive' apt-get update

sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y apptainer

