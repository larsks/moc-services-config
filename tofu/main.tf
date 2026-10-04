provider "ldap" {
  host          = var.ldap_host
  port          = var.ldap_port
  bind_user     = var.ldap_bind_dn
  bind_password = var.ldap_bind_password
}

# The backend and mapping tree for dc=massopen,dc=cloud are applied from
# base/dirsrv/ldif/backend.ldif when the dirsrv pod starts. The root entry below
# requires that routing to exist first.
resource "ldap_entry" "suffix" {
  dn = "dc=massopen,dc=cloud"

  data_json = jsonencode({
    objectClass = ["top", "domain"]
  })
}

resource "ldap_entry" "people" {
  dn = "ou=people,${ldap_entry.suffix.dn}"

  data_json = jsonencode({
    objectClass = ["top", "organizationalUnit"]
    aci = [
      "(targetattr = \"nsSshPublicKey || wireguardPublicKey\")(version 3.0; acl \"Keycloak manages public keys\"; allow (read, write) (userdn = \"ldap:///${coalesce(var.keycloak_ldap_bind_dn, var.ldap_bind_dn)}\");)"
    ]
  })

}

resource "ldap_entry" "groups" {
  dn = "ou=groups,${ldap_entry.suffix.dn}"

  data_json = jsonencode({
    objectClass = ["top", "organizationalUnit"]
  })
}

resource "ldap_entry" "admins" {
  dn = "cn=admins,${ldap_entry.groups.dn}"

  data_json = jsonencode({
    objectClass = ["top", "groupOfNames"]
  })

  # Group membership is intentionally left for a separate resource/configuration.
  ignore_attributes = ["member"]
}
