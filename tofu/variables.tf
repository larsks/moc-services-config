variable "ldap_host" {
  description = "Host running the directory server instance."
  type        = string
  default     = "localhost"
}

variable "ldap_port" {
  description = "LDAP port for the directory server instance."
  type        = number
  default     = 3389
}

variable "ldap_bind_dn" {
  description = "Bind DN with permission to create entries under the directory suffix."
  type        = string
  default     = "cn=Directory Manager"
}

variable "ldap_bind_password" {
  description = "Password for the LDAP bind DN. Set with TF_VAR_ldap_bind_password."
  type        = string
  sensitive   = true
}

variable "sssd_bind_password" {
  description = "Password for the uid=sssd-bind service account used by SSSD clients for POSIX lookups. Set with TF_VAR_sssd_bind_password."
  type        = string
  sensitive   = true
}

variable "keycloak_url" {
  description = "Scheme and host for the Keycloak admin API."
  type        = string
  default     = "http://localhost:7080"
}

variable "keycloak_base_path" {
  description = "Context path where Keycloak is exposed."
  type        = string
  default     = "/keycloak"
}

variable "keycloak_ldap_host" {
  description = "LDAP hostname as reachable from Keycloak inside the kind cluster."
  type        = string
  default     = "dirsrv.dirsrv.svc.cluster.local"
}

variable "keycloak_ldap_port" {
  description = "LDAPS port as reachable from Keycloak inside the kind cluster."
  type        = number
  default     = 3636
}

variable "keycloak_ldap_bind_dn" {
  description = "Optional bind DN Keycloak uses for LDAP federation; defaults to ldap_bind_dn."
  type        = string
  default     = ""
}

variable "keycloak_ldap_bind_password" {
  description = "Optional password for the Keycloak LDAP bind DN; defaults to ldap_bind_password."
  type        = string
  sensitive   = true
  default     = ""
}
