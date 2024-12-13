# These are local vars set for convenience and readability.
# Please note that $PROJECT_ID and $SHORT_SHA are substituted by the Cloud Build environment.
locals {
  # This is the name of the Cloud Build service account, which the GCP project generates when enabled.
  cloudbuild_serviceaccount   = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
  
  # This is the full name of the service account for out token service.
  auth_serviceaccount         = "${var.auth_service_acct_name}@${var.project}.iam.gserviceaccount.com"
  
  # This is the name of the container image we will be storing in Container Registry
  image_name                  = "gcr.io/$PROJECT_ID/${var.service}"

  # This is the name of the specific version of the container image built and stored. 
  # The $SHORT_SHA corresponds to the short sha of the latest git commit that triggers the build job.
  image_name_versioned        = "${local.image_name}:$SHORT_SHA"

  # This is creates a tag string for the latest image of the service.
  image_name_latest           = "${local.image_name}:latest"
}

# This defines the cloud provider to terraform, in this case GCP.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.42.1"
    }
  }
}

# This gives terraform the ability to affect GCP resources in your specified project.
# It requires terraform service account credentials in json format.
# The first time this terraform is applied, it will need to run locally, 
# and will reference a local credentials file.
# After the first run, the cloud build job will exist, and will run when code updates are pushed to Github.
# On those subsequent runs, the credentials json blob will be passed in via cloud build.
provider "google" {
  # If cloud build passes a credentials blob, use that, otherwise look for local credentials.
  credentials = var.credentials ? var.credentials : file(var.credentials_file)
  project = var.project
  region  = var.region
  zone    = var.zone
}

# Start activating needed GCP service APIs, allowing for resource changes via code
resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}
# End service activation


# The block below creates the Cloud Run service.
# Remove its comments after the first terraform run. It relies on the Cloud Build service to exist,
# because it builds the container image the token service relies on.

resource "google_cloud_run_service" "looker_gcp_auth_service" {
  name = var.service
  location = var.region

  template {
    spec {
      service_account_name = local.auth_serviceaccount
      containers {
        # this image is built by the Cloud Build job
        image = "gcr.io/${var.project}/${var.service}:${var.app_version}"
      }
    }
  }

#   # Waits for the Cloud Run API to be enabled
  depends_on = [google_project_service.run_api]
}

# Create public access for our cloud run service
# Auth will be handled internally via the service & Looker
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# Enables public access on Cloud Run service
resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.looker_gcp_auth_service.location
  project     = var.project
  service     = google_cloud_run_service.looker_gcp_auth_service.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

# This creates the cloud build trigger that runs on pushes to the main branch of the github repo 
# storing the token service project.
resource "google_cloudbuild_trigger" "deploy_main" {
  github {
    owner = var.github_acct
    name  = var.github_repo

    push {
      branch = "main"
    }
  }

  build {
    timeout = "1200s"

    # This step builds the Docker image for our project, 
    # passing the needed args for build env vars,
    # as well as tagging the image.
    step {
      id   = "docker build"
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "--build-arg", "LOOKERSDK_BASE_URL=${var.lookersdk_base_url}",
        "--build-arg", "SERVER_PORT=8080",
        "--build-arg", "SERVICE_ACCOUNT_EMAIL=${local.auth_serviceaccount}",
        "-t", local.image_name_versioned,
        "-t", local.image_name_latest,
        ".",
        "--build-arg", "BUILDKIT_INLINE_CACHE=1"
      ]
    }

    # This step pushes the new version to Cloud Repository
    step {
      id   = "docker push version"
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.image_name_versioned]
    }

    # This step pushes the latest version to Cloud Repository
    step {
      id   = "docker push latest"
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.image_name_latest]
    }

    # This steps initializes the latest version of Terraform
    step {
      id   = "tf init"
      name = "hashicorp/terraform:1.0.0"
      dir  = "terraform"
      args = ["init", "-upgrade"]
    }

    # This step runs terraform plan including variables for project id, image version, and credentials
    step {
      id   = "tf plan"
      name = "hashicorp/terraform:1.0.0"
      dir  = "terraform"
      args = ["plan", "-var", "project=$PROJECT_ID", "-var", "app_version=$SHORT_SHA"]
      secret_env = ["TF_VAR_credentials"]
    }

    # This step applies this terrraform, including variables for project id, image version, and credentials
    step {
      id   = "tf apply"
      name = "hashicorp/terraform:1.0.0"
      dir  = "terraform"
      args = ["apply", "-var", "project=$PROJECT_ID", "-var", "app_version=$SHORT_SHA", "-auto-approve"]
      secret_env = ["TF_VAR_credentials"]
    }

    # This block exposes the credentials blob, stored in GCP secrets to this Cloud Build job.
    available_secrets {
      secret_manager {
        env          = "TF_VAR_credentials"
        version_name = var.credentials_secret
      }
    }

    # This build kit option caches any artifacts of the build that can be reused on subsequent runs. 
    options {
      env = ["DOCKER_BUILDKIT=1"]
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}