#!/bin/sh

SSSD_BIND_PASSWORD=$(oc -n dirsrv extract secret/sssd-bind-credentials --to=- 2>/dev/null)
DIRSRV_CRT=$(oc -n dirsrv extract secret/dirsrv-ca --keys=tls.crt --to=-)

cat <<END_SCRIPT
#!/bin/sh

setenforce 0
cat >/etc/selinux/config <<EOF
SELINUX=permissive
SELINUXTYPE=targeted
EOF

mkdir -m 700 -p /root/.ssh
cat > /root/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFVJHRH2xg2joG1xJIrNTalRkzT6BM8rQT+OXoFiKn16 lars@oddbit.com
EOF
chmod 600 /root/.ssh/authorized_keys

dnf -y install openldap-clients sssd sssd-ldap sssd-common oddjob oddjob-mkhomedir

: >/etc/ssh/sshd_config.d/50-cloud-init.conf

cat >/etc/ssh/sshd_config.d/root.conf <<EOF
PermitRootLogin prohibit-password
EOF

cat >/etc/ssh/sshd_config.d/sssd.conf <<EOF
AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys %u
AuthorizedKeysCommandUser nobody
EOF

if ! grep -q dirsrv /etc/hosts; then
  cat >> /etc/hosts <<EOF
192.168.1.100 dirsrv
EOF
fi

cat >/etc/sssd/sssd.conf <<EOF
[sssd]
services = nss, pam, ssh
domains = default
EOF

cat >/etc/sssd/conf.d/ldap.conf <<EOF
[domain/default]
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap

# LDAP Server Details
ldap_uri = ldaps://dirsrv:3636
ldap_search_base = dc=massopen,dc=cloud

# SSH Public Key mapping
ldap_user_ssh_public_key = nsSshPublicKey

# Caching and Performance
cache_credentials = True
min_id = 10000

# Bind credentials for POSIX lookups
ldap_default_bind_dn = uid=sssd-bind,ou=services,dc=massopen,dc=cloud
ldap_default_authtok = $SSSD_BIND_PASSWORD
EOF

chmod 600 /etc/sssd/sssd.conf /etc/sssd/conf.d/ldap.conf

cat >/root/dirsrv.crt <<EOF
$DIRSRV_CRT
EOF

trust anchor --store /root/dirsrv.crt

systemctl restart sshd
systemctl enable --now oddjobd sssd
authselect select sssd with-mkhomedir
END_SCRIPT
