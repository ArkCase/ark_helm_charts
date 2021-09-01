#!/bin/bash

helm upgrade --install -n arkcase \
        --set nameOverride=snowbound \
        --set fullnameOverride=snowbound \
        --set arkcase_protocol=http \
        --set arkcase_host=13.126.43.123 \
        --set arkcase_port=443 \
        --set persistence.storageClass=gp2 \
        snowbound .
