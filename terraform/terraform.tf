variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "The region where the token service will reside."
}

variable "zone" {
  type        = string
  default     = "asia-southeast1-a"
  description = "The zone where the token service will reside."
}

variable "service" {
  type        = string
  default     = "looker-gcp-auth-service"
  description = "Name of the Cloud Run instance of the token server."
}

variable "project" {
  type        = string
  description = "The GCP project name where your service will reside."
}

variable "project_number" {
  type        = string
  description = "The GCP project id for your service."
}

variable "credentials" {
  type        = string
  description = "Secret credentials that will be passed to terraform when the Cloud Build job runs."
}

variable "credentials_file" {
  type        = string
  description = "The path to a local GCP credentials file for the initial terraform run."
}

variable "credentials_secret" {
  type        = string
  description = "The path to the GCP secret storing the terraform credentials above."
}

variable "lookersdk_base_url" {
  type        = string
  description = "The base url for the Looker instance from which the user is authenticating."
}

variable "auth_service_acct_name" {
  type        = string
  description = "The name of the GCP service account assoticated with this token service."
}

variable "github_acct" {
  type        = string
  description = "The github account where the token server repo is stored."
}

variable "github_repo" {
  type        = string
  description = "The name of the github repo where the token server project is stored"
}

variable "app_version" {
  type        = string
  description = "A short hash of latest git commit used to target the version of the service which should be built or deployed."
}