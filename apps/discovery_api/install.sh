#!/bin/bash
set -ex
helm init --client-only
helm upgrade --install discovery-api ./chart \
    --namespace=discovery \
    -f prod.yaml \
    --set ingress.scheme="${INGRESS_SCHEME}" \
    --set ingress.subnets="$PUBLIC_SUBNETS" \
    --set ingress.security_groups="${ALLOW_WEB_TRAFFIC_SG}" \
    --set ingress.dns_zone="${ENVIRONMENT}.internal.smartcolumbusos.com" \
    --set ingress.certificate_arn="${CERTIFICATE_ARN}" \
    --set image.tag="${IMAGE_TAG}" \
    --set service.auth_string="c2EtZGlzY292ZXJ5LWFwaTp2WEs0aU9wRmNnNlR1T1ZXT1RCcDNRQ1BURm56UHRLQ1A5V1B3M3ds" \
    --timeout=600 \
    --wait
