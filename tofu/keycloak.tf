provider "keycloak" {
  url       = var.keycloak_url
  base_path = var.keycloak_base_path
  client_id = "admin-cli"
  realm     = "master"
  # KEYCLOAK_USER and KEYCLOAK_PASSWORD are read from the environment.
}

resource "keycloak_realm" "moc" {
  realm       = "moc"
  enabled     = true
  remember_me = true
}

resource "keycloak_realm_user_profile" "moc" {
  realm_id                   = keycloak_realm.moc.id
  unmanaged_attribute_policy = "DISABLED"

  attribute {
    name         = "username"
    display_name = "$${username}"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        min = "3"
        max = "255"
      }
    }

    validator {
      name = "username-prohibited-characters"
    }

    validator {
      name = "up-username-not-idn-homograph"
    }
  }

  attribute {
    name         = "email"
    display_name = "$${email}"

    required_for_roles = ["user"]

    permissions {
      view = ["admin", "user"]
      edit = ["admin"]
    }

    validator {
      name = "email"
    }

    validator {
      name = "length"
      config = {
        max = "255"
      }
    }
  }

  attribute {
    name         = "firstName"
    display_name = "$${firstName}"

    required_for_roles = ["user"]

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        max = "255"
      }
    }

    validator {
      name = "person-name-prohibited-characters"
    }
  }

  attribute {
    name         = "lastName"
    display_name = "$${lastName}"

    required_for_roles = ["user"]

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        max = "255"
      }
    }

    validator {
      name = "person-name-prohibited-characters"
    }
  }

  attribute {
    name         = "sshPublicKey"
    display_name = "SSH public keys"
    multi_valued = true

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        max = "8192"
      }
    }

    validator {
      name = "multivalued"
      config = {
        max = "20"
      }
    }
  }

  attribute {
    name         = "wireguardPublicKey"
    display_name = "WireGuard public keys"
    multi_valued = true

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        max = "255"
      }
    }

    validator {
      name = "multivalued"
      config = {
        max = "20"
      }
    }
  }
}

resource "keycloak_ldap_user_federation" "directory" {
  name     = "dirsrv"
  realm_id = keycloak_realm.moc.id
  enabled  = true

  vendor         = "RHDS"
  edit_mode      = "WRITABLE"
  import_enabled = true
  trust_email    = true

  username_ldap_attribute = "uid"
  rdn_ldap_attribute      = "uid"
  uuid_ldap_attribute     = "nsUniqueId"
  user_object_classes = [
    "top",
    "person",
    "organizationalPerson",
    "inetOrgPerson",
    "nsAccount",
    "wireguardAccount",
  ]

  connection_url  = "ldaps://${var.keycloak_ldap_host}:${var.keycloak_ldap_port}"
  users_dn        = "ou=people,dc=massopen,dc=cloud"
  bind_dn         = coalesce(var.keycloak_ldap_bind_dn, var.ldap_bind_dn)
  bind_credential = coalesce(var.keycloak_ldap_bind_password, var.ldap_bind_password)

  search_scope                    = "ONE_LEVEL"
  connection_pooling              = true
  start_tls                       = false
  use_password_modify_extended_op = true
  use_truststore_spi              = "ALWAYS"

  changed_sync_period = 1800
  full_sync_period    = 604800

  # Keycloak creates default LDAP mappers for these user attributes. Remove
  # them so the explicit mapper resources below are the only mappings.
  delete_default_mappers = true
}

resource "keycloak_ldap_user_attribute_mapper" "username" {
  name                    = "username"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  user_model_attribute        = "username"
  ldap_attribute              = "uid"
  read_only                   = true
  always_read_value_from_ldap = true
  is_mandatory_in_ldap        = true
}

resource "keycloak_ldap_user_attribute_mapper" "email" {
  name                    = "email"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  user_model_attribute        = "email"
  ldap_attribute              = "mail"
  read_only                   = true
  always_read_value_from_ldap = true
  is_mandatory_in_ldap        = false
}

resource "keycloak_ldap_user_attribute_mapper" "first_name" {
  name                    = "first name"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  user_model_attribute        = "firstName"
  ldap_attribute              = "givenName"
  read_only                   = false
  always_read_value_from_ldap = true
  is_mandatory_in_ldap        = true
}

resource "keycloak_ldap_user_attribute_mapper" "last_name" {
  name                    = "last name"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  user_model_attribute        = "lastName"
  ldap_attribute              = "sn"
  read_only                   = false
  always_read_value_from_ldap = true
  is_mandatory_in_ldap        = true
}

resource "keycloak_ldap_user_attribute_mapper" "ssh_public_key" {
  name                    = "SSH public keys"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  user_model_attribute        = "sshPublicKey"
  ldap_attribute              = "nsSshPublicKey"
  read_only                   = false
  always_read_value_from_ldap = true
  is_mandatory_in_ldap        = false
}

resource "keycloak_ldap_user_attribute_mapper" "wireguard_public_key" {
  name                    = "WireGuard public keys"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  user_model_attribute        = "wireguardPublicKey"
  ldap_attribute              = "wireguardPublicKey"
  read_only                   = false
  always_read_value_from_ldap = true
  is_mandatory_in_ldap        = false
}

resource "keycloak_ldap_group_mapper" "groups" {
  name                    = "dirsrv-groups"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  ldap_groups_dn                 = "ou=groups,dc=massopen,dc=cloud"
  group_name_ldap_attribute      = "cn"
  group_object_classes           = ["groupOfNames"]
  membership_attribute_type      = "DN"
  membership_ldap_attribute      = "member"
  membership_user_ldap_attribute = "uid"
  mode                           = "READ_ONLY"
}

resource "keycloak_group" "ldapusers" {
  realm_id = keycloak_realm.moc.id
  name     = "ldapusers"
}

# Static (hardcoded) group mapper: every user imported from dirsrv is made a
# member of the ldapusers group, regardless of their LDAP group membership.
resource "keycloak_ldap_hardcoded_group_mapper" "ldapusers" {
  name                    = "ldapusers"
  realm_id                = keycloak_realm.moc.id
  ldap_user_federation_id = keycloak_ldap_user_federation.directory.id

  group = keycloak_group.ldapusers.path
}
