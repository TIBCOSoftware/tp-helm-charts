{{/* 
Copyright © 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
================================================================
                  SECTION VALIDATION
================================================================   
*/}}

{{- define "claims.validate" }}

{{/* validation for commonResourcePrefix claims */}}
{{- if not .Values.commonResourcePrefix }}
{{- fail (printf "crossplane-components.claims.commonResourcePrefix is required to be passed as helm values\nPlease set commonResourcePrefix as a string of MAXIMUM 10 lowercase alphanumeric characters (starting with an alphabet) which can include 1 hyphen (-), but not end with it, e.g. dev-1\nSet a unique name for each claims chart installation") }}
{{- end }}
{{- if or (not (mustRegexMatch "^[a-z][a-z0-9]*[-]?[a-z0-9]+$" .Values.commonResourcePrefix)) (gt (len .Values.commonResourcePrefix) 10) }}
{{- fail (printf "crossplane-components.claims.commonResourcePrefix must be a string of MAXIMUM 10 lowercase alphanumeric characters (starting with an alphabet) which can include 1 hyphen (-), but not end with it, e.g. dev-1") -}}
{{- end }}

{{/* validation for efs claims */}}
{{- if eq .Values.efs.create true }}
{{- if not .Values.efs.connectionDetailsSecret }}
{{- fail (printf "crossplane-components.claims.efs.connectionDetailsSecret is required to be passed as helm values") }}
{{- end }}
{{- if not .Values.efs.mandatoryConfigurationParameters }}
{{- fail (printf "crossplane-components.claims.efs.mandatoryConfigurationParameters are required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.efs.mandatoryConfigurationParameters.performanceMode }}
{{- fail (printf "crossplane-components.claims.efs.mandatoryConfigurationParameters.performanceMode is required to be passed as helm values") }}
{{- end }}
{{- if not .Values.efs.mandatoryConfigurationParameters.throughputMode }}
{{- fail (printf "crossplane-components.claims.efs.mandatoryConfigurationParameters.throughputMode is required to be passed as helm values") }}
{{- end }}
{{- if eq .Values.efs.storageClass.create true }}
{{- if not .Values.efs.storageClass.name }}
{{- fail (printf "crossplane-components.claims.efs.storageClass.name is required to be passed as helm values") }}
{{- end }}
{{- end }}
{{- if eq .Values.efs.persistentVolume.create true }}
{{- if not .Values.efs.persistentVolume.name }}
{{- fail (printf "crossplane-components.claims.efs.persistentVolume.name is required to be passed as helm values") }}
{{- end }}
{{- end }}
{{- if and (.Values.efs.persistentVolume) (.Values.efs.storageClass) }}
{{- if and (eq .Values.efs.persistentVolume.create true) (eq .Values.efs.storageClass.create true) }}
{{- fail (printf "crossplane-components.claims.efs.persistentVolume and crossplane-components.claims.efs.storageClass both cannot be created at the same time") }}
{{- end }}
{{- end }}
{{- end }}

{{/* validation for postgresInstance claims */}}
{{- if eq .Values.postgresInstance.create true }}
{{- if not .Values.postgresInstance.connectionDetailsSecret }}
{{- fail (printf "crossplane-components.claims.postgresInstance.connectionDetailsSecret is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.postgresInstance.mandatoryConfigurationParameters }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters are required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.postgresInstance.mandatoryConfigurationParameters.dbInstanceClass }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters.dbInstanceClass is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.postgresInstance.mandatoryConfigurationParameters.dbName }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters.dbName is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.postgresInstance.mandatoryConfigurationParameters.engine }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters.engine is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.postgresInstance.mandatoryConfigurationParameters.engineVersion }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters.engineVersion is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.postgresInstance.mandatoryConfigurationParameters.masterUsername }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters.masterUsername is required to be passed as helm values") -}}
{{- end }}
{{- if empty .Values.postgresInstance.mandatoryConfigurationParameters.port }}
{{- fail (printf "crossplane-components.claims.postgresInstance.mandatoryConfigurationParameters.port is required to be passed as helm values") -}}
{{- end }}
{{- end }}

{{/* validation for aurora cluster and global database claims */}}
{{- if eq .Values.auroraCluster.create true }}
{{- if not .Values.auroraCluster.connectionDetailsSecret }}
{{- fail (printf "crossplane-components.claims.auroraCluster.connectionDetailsSecret is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters are required to be passed as helm values") -}}
{{- end }}
{{/*
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.dbParameterGroupFamily }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.dbParameterGroupFamily is required to be passed as helm values") -}}
{{- end }}
*/}}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.dbInstanceClass }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.dbInstanceClass is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.engine }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.engine is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.engineVersion }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.engineVersion is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.engineMode }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.engineMode is required to be passed as helm values") -}}
{{- end }}
{{- if empty .Values.auroraCluster.mandatoryConfigurationParameters.port }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.port is required to be passed as helm values") -}}
{{- end }}
{{- if .Values.auroraCluster.globalDatabase }}
{{- if and (.Values.auroraCluster.globalDatabase.primaryCluster.create) (.Values.auroraCluster.globalDatabase.secondaryCluster.create) -}}
{{- fail (printf "only one of crossplane-components.claims.auroraCluster.globalDatabase.primaryCluster or crossplane-components.claims.auroraCluster.globalDatabase.secondaryCluster is required to be passed as helm values") -}}
{{- end }}
{{- if (not (.Values.auroraCluster.globalDatabase.secondaryCluster.create)) }}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.databaseName }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.databaseName is required to be passed as helm values for primary cluster") -}}
{{- end }}
{{- if not .Values.auroraCluster.mandatoryConfigurationParameters.masterUsername }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.masterUsername is required to be passed as helm values for primary cluster") -}}
{{- end }}
{{- end }}
{{- if and .Values.auroraCluster.globalDatabase.primaryCluster }}
{{- if and (.Values.auroraCluster.globalDatabase.primaryCluster.create) (not (.Values.auroraCluster.globalDatabase.secondaryCluster.create)) }}
{{- if empty .Values.auroraCluster.globalDatabase.primaryCluster.deletionProtection }}
{{- fail (printf "crossplane-components.claims.auroraCluster.globalDatabase.primaryCluster.deletionProtection is required to be passed as helm values") -}}
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.auroraCluster.globalDatabase.secondaryCluster }}
{{- if and (.Values.auroraCluster.globalDatabase.secondaryCluster.create) (not (.Values.auroraCluster.globalDatabase.primaryCluster.create)) }}
{{- if not .Values.auroraCluster.globalDatabase.secondaryCluster.globalClusterIdentifier }}
{{- fail (printf "crossplane-components.claims.auroraCluster.globalDatabase.secondaryCluster.globalClusterIdentifier is required to be passed as helm values") -}}
{{- end }}
{{- if .Values.auroraCluster.mandatoryConfigurationParameters.databaseName }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.databaseName is not required to be passed as helm values for secondary cluster") -}}
{{- end }}
{{- if .Values.auroraCluster.mandatoryConfigurationParameters.masterUsername }}
{{- fail (printf "crossplane-components.claims.auroraCluster.mandatoryConfigurationParameters.masterUsername is not required to be passed as helm values for secondary cluster") -}}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* validation for redis claims */}}
{{- if eq .Values.redis.create true }}
{{- if not .Values.redis.connectionDetailsSecret }}
{{- fail (printf "crossplane-components.claims.redis.connectionDetailsSecret is required to be passed as helm values") }}
{{- end }}
{{- if not .Values.redis.mandatoryConfigurationParameters }}
{{- fail (printf "crossplane-components.claims.redis.mandatoryConfigurationParameters are required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.redis.mandatoryConfigurationParameters.cacheNodeType }}
{{- fail (printf "crossplane-components.claims.redis.mandatoryConfigurationParameters.cacheNodeType is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.redis.mandatoryConfigurationParameters.cacheParameterGroupName }}
{{- fail (printf "crossplane-components.claims.redis.mandatoryConfigurationParameters.cacheParameterGroupName is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.redis.mandatoryConfigurationParameters.engineVersion }}
{{- fail (printf "crossplane-components.claims.redis.mandatoryConfigurationParameters.engineVersion is required to be passed as helm values") -}}
{{- end }}
{{- if empty .Values.redis.mandatoryConfigurationParameters.port }}
{{- fail (printf "crossplane-components.claims.redis.mandatoryConfigurationParameters.port is required to be passed as helm values") -}}
{{- end }}
{{- end }}

{{/* validation for ses claims */}}
{{- if eq .Values.ses.create true }}
{{- if not .Values.ses.connectionDetailsSecret }}
{{- fail (printf "crossplane-components.claims.ses.connectionDetailsSecret is required to be passed as helm values") }}
{{- end }}
{{- if not .Values.ses.mandatoryConfigurationParameters }}
{{- fail (printf "crossplane-components.claims.ses.mandatoryConfigurationParameters are required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.ses.mandatoryConfigurationParameters.emailIdentity }}
{{- fail (printf "crossplane-components.claims.ses.mandatoryConfigurationParameters.emailIdentity is required to be passed as helm values") -}}
{{- end }}
{{- end }}

{{/* validation for iam claims */}}
{{- if eq .Values.iam.create true }}
{{- if not .Values.iam.connectionDetailsSecret }}
{{- fail (printf "crossplane-components.claims.iam.connectionDetailsSecret is required to be passed as helm values") }}
{{- end }}
{{- if not .Values.iam.mandatoryConfigurationParameters }}
{{- fail (printf "crossplane-components.claims.iam.mandatoryConfigurationParameters are required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.iam.mandatoryConfigurationParameters.serviceAccount }}
{{- fail (printf "crossplane-components.claims.iam.mandatoryConfigurationParameters.serviceAccount are required to be passed as helm values") -}}
{{- end }}
{{- if eq .Values.iam.mandatoryConfigurationParameters.serviceAccount.create true}}
{{- if not .Values.iam.mandatoryConfigurationParameters.serviceAccount.name }}
{{- fail (printf "crossplane-components.claims.iam.mandatoryConfigurationParameters.serviceAccount.name is required to be passed as helm values") -}}
{{- end }}
{{- if not .Values.iam.mandatoryConfigurationParameters.serviceAccount.namespace }}
{{- fail (printf "crossplane-components.claims.iam.mandatoryConfigurationParameters.serviceAccount.namespace is required to be passed as helm values") -}}
{{- end }}
{{- end }}
{{- end }}
{{- end }}