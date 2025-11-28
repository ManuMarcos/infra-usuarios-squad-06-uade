variable "access_key" {
  description = "access_key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "secret_key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "region"
  type        = string
  sensitive   = false
}



# --- Variables de Aplicación (SENSIBLES) ---
variable "postgres_password_prod" {
  description = "Contraseña de la base de datos de producción."
  type        = string
  sensitive   = true
}

variable "ldap_admin_password_prod" {
  description = "Contraseña de administración LDAP de producción."
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key para S3."
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS Access Key para S3."
  type        = string
}

# --- Variables de Configuración de la Aplicación ---
variable "backend_host_port" {
  description = "Puerto del host de la EC2 que expone el Backend."
  type        = number
  default     = 8081
}