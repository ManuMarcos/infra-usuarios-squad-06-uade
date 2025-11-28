#!/bin/bash
# -----------------------------------------------
# 0. Variables de Entorno
# -----------------------------------------------
APP_DIR="/var/www/app"
BACKEND_HOST_PORT="8081" 

FRONTEND_SOURCE_FOLDER="arreglaya" 
FRONTEND_BUILD_FOLDER="build" 

# URL del repositorio de Frontend
FRONTEND_REPO="https://github.com/ManuMarcos/Frontend-usuarios-squad-06-uade.git" 
# URL del repositorio de Backend
BACKEND_REPO="https://github.com/ManuMarcos/backend-usuarios-squad-06-uade.git" 

# -----------------------------------------------
# 1. Instalación de Dependencias 
# -----------------------------------------------
sudo apt-get update
# Instalar Nginx, Docker, Git y utilidades
sudo apt-get install -y docker.io docker-compose git nginx curl

# Instalar Node.js y npm (para compilar React)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl enable nginx

# -----------------------------------------------
# 2. Descarga de Códigos y Compilación del Frontend
# -----------------------------------------------
sudo mkdir -p $APP_DIR
cd $APP_DIR

# Clonar Repositorios
git clone $BACKEND_REPO backend
git clone $FRONTEND_REPO frontend

# --- COMPILACIÓN DEL FRONTEND ---
# Entrar al directorio donde está el package.json (la subcarpeta 'arreglaya')
cd $APP_DIR/frontend/$FRONTEND_SOURCE_FOLDER

# Instalar dependencias
npm install

# Compilar el proyecto React
npm run build 

# Volver al directorio raíz de la aplicación
cd $APP_DIR

# -----------------------------------------------
# 3. Despliegue del Backend (con Docker Compose)
# -----------------------------------------------
cd $APP_DIR/backend

# Crear el archivo .env.prod con los valores de PROD
sudo tee .env.prod > /dev/null <<EOF
# --- POSTGRES ---
POSTGRES_HOST_PROD=postgres-prod
POSTGRES_PORT_PROD=5432
POSTGRES_DB_PROD=users_db_prod
POSTGRES_USER_PROD=admin_prod
POSTGRES_PASSWORD_PROD=${PG_PASS}

# --- SERVIDOR ---
SERVER_PORT_PROD=8080

# --- LDAP PROD ---
LDAP_SERVER_PROD=ldap://ldap-prod
LDAP_DOMAIN_PROD=arreglaya.com
LDAP_BASE_DN_PROD=dc=arreglaya,dc=com
LDAP_USER_PROD=cn=admin,dc=arreglaya,dc=com
LDAP_ADMIN_PASSWORD_PROD=${LDAP_PASS}
LDAP_ORGANISATION_PROD="Arregla ya ldap prod"

# --- AWS CREDENCIALES ---
AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
AWS_SECRET_KEY=${AWS_SECRET_KEY}
AWS_S3_BUCKET=${S3_BUCKET_NAME}
EOF

sudo docker-compose --env-file .env.prod up -d

# Volver al directorio raíz para Nginx
cd $APP_DIR

# -----------------------------------------------
# 4. Configuración del Reverse Proxy (Nginx en el Host EC2)
# -----------------------------------------------
NGINX_CONF="/etc/nginx/sites-available/app_proxy"


sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    # ========================
    #   FRONTEND (REACT Compilado)
    # ========================
    # RUTA CORREGIDA: Apunta a la carpeta de BUILD dentro de la carpeta fuente.
    root $APP_DIR/frontend/$FRONTEND_SOURCE_FOLDER/$FRONTEND_BUILD_FOLDER;

    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # ========================
    #   BACKEND (SPRING DEV)
    # ========================
    location /api/ {
        proxy_pass http://127.0.0.1:$BACKEND_HOST_PORT/api/; 

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;

        if (\$request_method = OPTIONS) {
            return 204;
        }
    }
}
EOF

# Activamos la nueva configuración y reiniciamos Nginx
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/default
sudo systemctl restart nginx