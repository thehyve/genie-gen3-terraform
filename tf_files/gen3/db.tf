module "arborist-db" {
  count                   = var.arborist_enabled ? 1 : 0
  source                  = "../aws/aurora_db"
  vpc_name                = var.vpc_name
  service                 = "arborist"
  admin_database_username = var.aurora_username
  admin_database_password = var.aurora_password
  namespace               = var.namespace
  create_db               = var.create_dbs
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
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
  create_db_job           = var.create_dbs_with_job
  secrets_manager_enabled = true
}

locals {
  db_names = {
    fence     = "fence_db"
    sheepdog  = "sheepdog_db"
    peregrine = "peregrine_db"
    indexd    = "indexb_db"
    arborist  = "arborist_db"
    metadata  = "metadata_db"
    audit     = "audit_db"
    requestor = "requestor_db"
  }
}


resource "kubernetes_config_map" "db_setup_script" {
  count = var.create_dbs && var.create_dbs_with_job ? 1 : 0
  metadata {
    name      = "db-setup-script"
    namespace = var.namespace
  }

  data = {
    "setup.sh" = <<-EOF
      #!/bin/bash
      set -e

      ADMIN_DB = "${ADMIN_DB:postgres}"
      read -ra DATABASES <<< "$DB_LIST"
      read -ra USERS <<< "$USER_LIST"
      read -ra PASSWORDS <<< "$PASS_LIST"

      for i in "$${!DATABASES[@]}"; do
        SVC_NAME="$${SERVICES[$i]}"
        DB_USER="$${USERS[$i]}"
        DB_PASS="$${PASSWORDS[$i]}"
        DB_NAME="$${DATABASES[$i]}"

        echo "------------------------------------------"
        echo "Processing: $DB_NAME"

        # Check/Create D"gen3_admin"B
        DB_EXISTS=$(psql -h $PGHOST -U $PGUSER -d $ADMIN_DB -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
        if [ "$DB_EXISTS" != "1" ]; then
          psql -h $PGHOST -U $PGUSER -d postgres $ADMIN_DB -c "CREATE DATABASE \"$DB_NAME\""
        fi

        psql -h $PGHOST -U $PGUSER -d $DB_NAME -c "
          DO 'BEGIN
             EXECUTE format(''
                IF EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = %I) THEN
                ALTER USER %I WITH PASSWORD %L;
                RAISE NOTICE 'User %I already exists. Updating password.'
             '', ''$DB_USER'',''$DB_USER'', ''$B_PASS'', ''$DB_USER'')
             ELSE
                BEGIN   -- nested block
                  EXCUTE format(''
                      CREATE USER %I LOGIN PASSWORD %L
                      EXCEPTION
                        WHEN duplicate_object THEN
                          RAISE NOTICE 'User %I was just created by a concurrent transaction. Skipping.'
                  '', ''$DB_USER'', ''$DB_PASS'', ''$DB_USER'')
                END;
             END IF;
          END';"
      done
    EOF
  }
}

resource "kubernetes_job" "fence_db_setup" {
  count = var.fence_enabled && var.create_dbs_with_job ? 1 : 0

  metadata {
    # Unique name ensures the job runs again if the script changes
    name      = "gen3-db-setup-${sha1(kubernetes_config_map.db_setup_script.data["setup.sh"])}"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {
        name = "gen3-db-setup"
      }
      spec {
        volume {
          name = "script-volume"
          config_map {
            name         = kubernetes_config_map.db_setup_script.metadata[0].name
            default_mode = "0755"
          }
        }

        container {
          name  = "psql-client"
          image = "postgres:17"

          command = ["/bin/bash", "/scripts/setup.sh"]

        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 1
  }

  wait_for_completion = true
  depends_on = [module.fence-db]
}

resource "kubernetes_job" "gen3_db_setup" {
  count = var.create_dbs && var.create_dbs_with_job ? 1 : 0
  metadata {
    # Unique name ensures the job runs again if the script changes
    name      = "gen3-db-setup-${sha1(kubernetes_config_map.db_setup_script.data["setup.sh"])}"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {
        name = "gen3-db-setup"
      }
      spec {
        volume {
          name = "script-volume"
          config_map {
            name         = kubernetes_config_map.db_setup_script.metadata[0].name
            default_mode = "0755"
          }
        }

        container {
          name  = "psql-client"
          image = "postgres:17"

          command = ["/bin/bash", "/scripts/setup.sh"]

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
            name  = "DATABASES"
            value = join(" ", [
              module.argo-db.database_name,
              module.arborist-db.database_name,
              module.audit-db.database_name,
              module.dicom-server-db.database_name,
              module.dicom-viewer-db.database_name,
              module.fence-db.database_name,
              module.indexd-db.database_name,
              module.metadata-db.database_name,
              module.requestor-db.database_name,
              module.sheepdog-db.database_name,
              module.wts-db.database_name,
            ])
          }
          env {
            name  = "USER_LIST"
            value = join(" ", [
              module.argo-db.database_username,
              module.arborist-db.database_username,
              module.audit-db.database_username,
              module.dicom-server-db.database_username,
              module.dicom-viewer-db.database_username,
              module.fence-db.database_username,
              module.indexd-db.database_username,
              module.metadata-db.database_username,
              module.requestor-db.database_username,
              module.sheepdog-db.database_username,
              module.wts-db.database_username,
            ])
          }
          env {
            name  = "PASS_LIST"
            value = join(" ",[
              module.argo-db.database_password,
              module.arborist-db.database_password,
              module.audit-db.database_password,
              module.dicom-server-db.database_password,
              module.dicom-viewer-db.database_password,
              module.fence-db.database_password,
              module.indexd-db.database_password,
              module.metadata-db.database_password,
              module.requestor-db.database_password,
              module.sheepdog-db.database_password,
              module.wts-db.database_password,
            ])
          }

          volume_mount {
            name       = "script-volume"
            mount_path = "/scripts"
          }
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 1
  }

  wait_for_completion = true
}

