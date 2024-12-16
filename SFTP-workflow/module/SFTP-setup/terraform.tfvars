# terraform.tfvars

sftp_bucket_name  = "XXXXXXXXXXXXXX"
sftp_server_name  = "my-sftp-server"
environment       = "production"
log_retention_days = 30
alert_email       = "admin@example.com"

sftp_users = {
  "user1" = {
    ssh_public_key = "ssh-rsa AAAA..."
  },
  "user2" = {
    ssh_public_key = "ssh-rsa AAAA..."
  }
}
