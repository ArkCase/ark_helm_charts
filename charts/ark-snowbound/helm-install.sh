#!/bin/bash

helm upgrade --install -n arkcase \
        --set nameOverride=snowbound \
        --set fullnameOverride=snowbound \
        --set snowbound_host_port=https://ec2-13-126-43-123.arkcase.com \
        --set arkcase_host_port=https://ec2-13-126-43-123.arkcase.com \
        --set persistence.storageClass=gp2 \
        snowbound .
