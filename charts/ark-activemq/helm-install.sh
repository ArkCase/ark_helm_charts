#!/bin/bash

helm upgrade --install -n arkcase \
        --set nameOverride=activemq \
        --set fullnameOverride=activemq \
        --set ports.console=8161 \
        --set ports.openwire=61616 \
        --set ports.stomp=61613 \
        --set persistence.storageClass=efs-sc \
        activemq .
