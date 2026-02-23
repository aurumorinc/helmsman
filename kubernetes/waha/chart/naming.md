# Naming Conventions

This document outlines the naming conventions used in the Waha Helm chart for resources.

## General
Prefix based on the Helm Release name (default: `waha`).

## Deployments
- **Main Instance**: `{{ .Release.Name }}-main` (e.g., `waha-main`)
- **User Instance**: `{{ .Release.Name }}-{{ .user.name }}` (e.g., `waha-aquiveal`)
- **Gateway**: `{{ .Release.Name }}-gateway` (e.g., `waha-gateway`)

## Services
- **Gateway (External)**: `{{ .Release.Name }}` (e.g., `waha`)
- **Main (Internal)**: `{{ .Release.Name }}-main`
- **User (Internal)**: `{{ .Release.Name }}-{{ .user.name }}`

## Secrets (ExternalSecrets)
- **Password (Shared)**: `password`
  - Keys: `dashboard-password`, `swagger-password`, `database-password`
- **API Key**: `api`
  - Key: `api-key`
- **S3 Access Key**: `access-key`
  - Keys: `access-key-id`, `secret-access-key`

## Databases
- **Main Instance**: `waha` (Default database)
- **User Instance**: `waha-{{ .user.name }}` (e.g., `waha-aquiveal`)

## URLs (Ingress/Gateway)
- **Main**: `https://<domain>/`
- **User**: `https://<domain>/user/{{ .user.name }}/`
