{{/*
Expand the name of the chart.
*/}}
{{- define "mlflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mlflow.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mlflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mlflow.labels" -}}
helm.sh/chart: {{ include "mlflow.chart" . }}
{{ include "mlflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mlflow.selectorLabels" -}}
app: {{ include "mlflow.name" . }}
app.kubernetes.io/name: {{ include "mlflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mlflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mlflow.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "mlflow.artifactCommand" -}}
{{- $artifactCommandPrefix := "default-artifact-root" }}
{{- $artifactCommand := printf "--%s=./mlruns" $artifactCommandPrefix }}

{{- if .Values.artifactRoot.proxiedArtifactStorage }}
  {{- $artifactCommandPrefix = "artifacts-destination" }}
  {{- $artifactCommand = printf "--%s=./mlartifacts" $artifactCommandPrefix }}
{{- end }}

{{- if .Values.artifactRoot.azureBlob.enabled }}
  {{ printf "--%s=wasbs://%s@%s.blob.core.windows.net/%s" $artifactCommandPrefix .Values.artifactRoot.azureBlob.container .Values.artifactRoot.azureBlob.storageAccount .Values.artifactRoot.azureBlob.path }}
{{- else if .Values.artifactRoot.s3.enabled }}
  {{ printf "--%s=s3://%s/%s" $artifactCommandPrefix .Values.artifactRoot.s3.bucket .Values.artifactRoot.s3.path }}
{{- else if .Values.artifactRoot.gcs.enabled }}
  {{ printf "--%s=gs://%s/%s" $artifactCommandPrefix .Values.artifactRoot.gcs.bucket .Values.artifactRoot.gcs.path }}
{{- end }}
{{- end }}

{{- define "mlflow.dbConnectionDriver" -}}
{{- $dbConnectionDriver := "" }}
{{- if and .Values.backendStore.postgres.enabled .Values.backendStore.postgres.driver }}
  {{ printf "+%s" .Values.backendStore.postgres.driver }}
{{- else if and .Values.backendStore.mysql.enabled .Values.backendStore.mysql.driver }}
  {{ printf "+%s" .Values.backendStore.mysql.driver }}
{{- end }}
{{- end }}

{{- define "mlflow.commandArgs" }}
{{- if .Values.overrideArgs }}
{{ toYaml .Values.overrideArgs }}
{{- else }}
- server
- --host=0.0.0.0
- --port={{ .Values.service.port }}
{{- if .Values.backendStore.postgres.enabled }}
- --backend-store-uri=postgresql{{ include "mlflow.dbConnectionDriver" . }}://
{{- else if .Values.backendStore.mysql.enabled }}
- --backend-store-uri=mysql{{ include "mlflow.dbConnectionDriver" }}://$(MYSQL_USERNAME):$(MYSQL_PWD)@$(MYSQL_HOST):$(MYSQL_TCP_PORT)/$(MYSQL_DATABASE)
{{- else }}
- --backend-store-uri=sqlite:///:memory
{{- end }}
- {{ include "mlflow.artifactCommand" . }}
{{- if .Values.artifactRoot.proxiedArtifactStorage }}
- --serve-artifacts
{{- end }}
{{- if .Values.serviceMonitor.enabled }}
- --expose-prometheus=/mlflow/metrics
{{- end }}
{{- range $key, $value := .Values.extraArgs }}
- --{{ kebabcase $key }}={{ $value }}
{{- end }}
{{- range .Values.extraFlags }}
- --{{ kebabcase . }}
{{- end }}
{{- end }}
{{- end }}