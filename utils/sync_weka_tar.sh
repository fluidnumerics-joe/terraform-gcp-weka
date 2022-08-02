#!/bin/bash

# you must pass get.weka.io token i.e. "TOKEN" as env var

version="4.0.0.70-gcp"
bucket_name="weka-installation"

curl -LO "https://$TOKEN@get.weka.io/dist/v1/pkg/weka-$version.tar"
gsutil cp weka-$version.tar gs://$bucket_name