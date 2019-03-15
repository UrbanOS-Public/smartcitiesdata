#!/bin/sh
    
wget https://dl.minio.io/client/mc/release/linux-amd64/mc -P /usr/bin/
chmod a+x /usr/bin/mc

sleep 10
mc config host add kdp http://minio:9000 admin V8f1CwQqAcwo80UEIJEjc5gVQUSSx5ohQ9GSrr12
mc mb kdp/kdp-cloud-storage
mc policy public kdp/kdp-cloud-storage