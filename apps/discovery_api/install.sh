#!/bin/bash
set -ex
helm init --client-only
helm upgrade --install discovery-api ./chart \
    --namespace=discovery \
    -f prod.yaml \
    --set ingress.scheme="${INGRESS_SCHEME}" \
    --set ingress.subnets=$(echo $PUBLIC_SUBNETS | sed 's/,/\\,/g') \
    --set ingress.security_groups="${ALLOW_WEB_TRAFFIC_SG}" \
    --set ingress.dns_zone="${ENVIRONMENT}.internal.smartcolumbusos.com" \
    --set ingress.certificate_arn="${CERTIFICATE_ARN}" \
    --set image.tag="${IMAGE_TAG}" \
    --set service.auth_string="YmlnYmFkYm9iOmZvb2JhcmJhejEyMw==" \
    --timeout=600 \
    --wait