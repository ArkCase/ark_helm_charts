#!/bin/bash

helm upgrade --install -n arkcase \
        --set nameOverride=snowbound \
        --set fullnameOverride=snowbound \
        snowbound .
