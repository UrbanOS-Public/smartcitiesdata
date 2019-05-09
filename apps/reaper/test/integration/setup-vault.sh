#!/bin/sh

vault login ${VAULT_DEV_ROOT_TOKEN}

vault policy write access /access.hcl

vault auth enable ldap

vault write auth/ldap/config \
      url="ldap://${LDAP_SERVER}:389" \
      starttls=false \
      insecure_tls=true \
      userdn="${USER_DN}" \
      userattr="${USER_ATTR}" \
      groupdn="${GROUP_DN}" \
      groupattr="${GROUP_ATTR}" \
      binddn="${BIND_DN}" \
      bindpass="${BIND_PASS}"

vault write auth/ldap/groups/${GROUP} policies=access

exit 0
