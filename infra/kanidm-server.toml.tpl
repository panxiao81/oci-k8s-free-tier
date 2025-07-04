# Kanidm Server Configuration
bindaddress = "0.0.0.0:8443"
domain = "${domain}"
origin = "${origin}"
db_path = "/data/kanidm.db"
tls_chain = "/data/tls/tls.crt"
tls_key = "/data/tls/tls.key"
log_level = "info"
trust_x_forward_for = false
role = "WriteReplica"