module "arborist-db" {
  count                   = var.arborist_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "arborist"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "argo-db" {
  count                   = var.argo_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "argo"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "audit-db" {
  count                   = var.audit_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "audit"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "dicom-viewer-db" {
  count                   = var.dicom-viewer_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "dicom"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "dicom-server-db" {
  count                   = var.dicom-server_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "dicom-server"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "fence-db" {
  count                   = var.fence_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "fence"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "indexd-db" {
  count                   = var.indexd_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "indexd"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "metadata-db" {
  count                   = var.metadata_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "metadata"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "requestor-db" {
  count                   = var.requestor_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "requestor"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "sheepdog-db" {
  count                   = var.sheepdog_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "sheepdog"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

module "wts-db" {
  count                   = var.wts_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "wts"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  secrets_manager_enabled = true
}

locals {
  active_database_modules = flatten([
    module.fence-db[*],
    module.wts-db[*],
    module.sheepdog-db[*],
    module.requestor-db[*],
    module.metadata-db[*],
    module.indexd-db[*],
    module.dicom-viewer-db[*],
    module.dicom-server-db[*],
    module.audit-db[*],
    module.arborist-db[*],
    module.argo-db[*],
  ])
}

resource "kubernetes_job" "db_setup_jobs" {
  for_each = {
    for module in local.active_database_modules :
      replace(module.database_name, "_", "-") => module
    if var.create_dbs_with_job
  }

  metadata {
    name      = "${each.key}-db-setup"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {
        name = "${each.key}-db-setup"
      }
      spec {
        container {
          name  = "psql-client"
          image = "postgres:17"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            set -e
            echo "Checking if database $TARGET_DB exists..."
            if psql -h "$PGHOST" -U "$PGUSER" -d "$ADMIN_DB" -tAc "SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB'" | grep -q 1; then
                echo "Database $TARGET_DB already exists."
            else
                echo "Database $TARGET_DB does not exist. Creating..."
                psql -h "$PGHOST" -U "$PGUSER" -d "$ADMIN_DB" -c "CREATE DATABASE \"$TARGET_DB\";"
            fi

            echo "Setting up user $TARGET_USER and permissions..."
            psql -h "$PGHOST" -U "$PGUSER" -d "$ADMIN_DB" <<EOF
            DO \$\$
            BEGIN
               IF EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$TARGET_USER') THEN
                  ALTER USER "$TARGET_USER" WITH PASSWORD '$TARGET_PASSWORD';
                  RAISE NOTICE 'User "$TARGET_USER" already exists. Updating password.';
               ELSE
                  CREATE USER "$TARGET_USER" LOGIN PASSWORD '$TARGET_PASSWORD';
               END IF;
            END
            \$\$;
            GRANT ALL ON DATABASE "$TARGET_DB" TO "$TARGET_USER" WITH GRANT OPTION;
            EOF
            
            echo "Database initialization for $TARGET_DB completed successfully."
            EOT
          ]
          env {
            name = "ADMIN_DB"
            value = "postgres"
          }
          env {
            name  = "PGHOST"
            value = var.aurora_hostname
          }
          env {
            name  = "PGUSER"
            value = var.aurora_username
          }
          env {
            name  = "PGPASSWORD"
            value = var.aurora_password
          }
          env {
            name  = "TARGET_DB"
            value = each.value.database_name
          }
          env {
            name  = "TARGET_USER"
            value = each.value.database_username
          }
          env {
            name  = "TARGET_PASSWORD"
            value = each.value.database_password
          }
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 1
  }

  wait_for_completion = true
  depends_on = [module.fence-db]
}
