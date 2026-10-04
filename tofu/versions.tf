terraform {
  required_version = ">= 1.13.0, < 2.0.0"

  required_providers {
    ldap = {
      source  = "l-with/ldap"
      version = "~> 0.13.2"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.9.0"
    }
  }
}
