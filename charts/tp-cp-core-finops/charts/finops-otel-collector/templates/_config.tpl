{{/*
Default memory limiter configuration for OpenTelemetry Collector based on k8s resource limits.
*/}}
{{- define "finops-otel-collector.memoryLimiter" -}}
# check_interval is the time between measurements of memory usage.
check_interval: 5s

# By default limit_mib is set to 80% of ".Values.resources.limits.memory"
limit_percentage: 80

# By default spike_limit_mib is set to 25% of ".Values.resources.limits.memory"
spike_limit_percentage: 25
{{- end }}

{{/*
Merge user supplied config into memory limiter config.
*/}}
{{- define "finops-otel-collector.baseConfig" -}}
{{- $processorsConfig := get .Values.config "processors" }}
{{- if not $processorsConfig.memory_limiter }}
{{-   $_ := set $processorsConfig "memory_limiter" (include "finops-otel-collector.memoryLimiter" . | fromYaml) }}
{{- end }}

{{- if .Values.useGOMEMLIMIT }}
  {{- if (((.Values.config).service).extensions) }}
    {{- $_ := set .Values.config.service "extensions" (without .Values.config.service.extensions "memory_ballast") }}
  {{- end}}
  {{- $_ := unset (.Values.config.extensions) "memory_ballast" }}
{{- else }}
  {{- $memoryBallastConfig := get .Values.config.extensions "memory_ballast" }}
  {{- if or (not $memoryBallastConfig) (not $memoryBallastConfig.size_in_percentage) }}
  {{-   $_ := set $memoryBallastConfig "size_in_percentage" 40 }}
  {{- end }}
{{- end }}

{{- .Values.config | toYaml }}
{{- end }}

{{/*
Build config file for daemonset OpenTelemetry Collector
*/}}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* Get control plane environment configuration value from a key. key = key name in configmap, default = If key not found or configmap does not exist then the return default  */}}
{{/* required = if this key is mandatory or not, Release = get cm namespace from inbuilt .Release object */}}
{{/* usage =  include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "true"  "Release" .Release )  */}}
{{- define "cp-env.get" }}
{{- $cm := ((include "cp-env" .)| fromYaml) }}
{{- if $cm }} {{- /* configmap exists */ -}}
  {{- if (hasKey $cm "data") }}
    {{- if (hasKey $cm.data .key) }}
      {{- $val := (get $cm.data .key) }}
      {{- $val }}
    {{- else -}} {{- /* key does not exists */ -}}
       {{- if eq .required "true" }}{{ fail (printf "%s missing key in configmap cp-env" .key)}}{{ else }}{{ .default }}{{ end }}
    {{- end -}}
  {{- else -}}{{- /* data key does not exists */ -}}
    {{- if eq .required "true" }}{{ fail (printf "data key missing in configmap cp-env")}}{{ else }}{{ .default }}{{ end }}
  {{- end }}
{{- else }} {{- /* configmap does not exists */ -}}
    {{- if eq .required "true" }}{{ fail (printf "missing configmap cp-env")}}{{ else }}{{ .default }}{{ end }}
{{- end }}
{{- end }}

{{- define "finops-otel-collector.daemonsetConfig" -}}
{{- $values := deepCopy .Values }}
{{- $data := dict "Values" $values | mustMergeOverwrite (deepCopy .) }}
{{- $config := include "finops-otel-collector.baseConfig" $data | fromYaml }}
{{- if .Values.presets.logsCollection.enabled }}
{{- $config = (include "finops-otel-collector.applyLogsCollectionConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.hostMetrics.enabled }}
{{- $config = (include "finops-otel-collector.applyHostMetricsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.kubeletMetrics.enabled }}
{{- $config = (include "finops-otel-collector.applyKubeletMetricsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.kubernetesAttributes.enabled }}
{{- $config = (include "finops-otel-collector.applyKubernetesAttributesConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.clusterMetrics.enabled }}
{{- $config = (include "finops-otel-collector.applyClusterMetricsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- tpl (toYaml $config) . }}
{{- end }}

{{/*
Build config file for deployment OpenTelemetry Collector
*/}}
{{- define "finops-otel-collector.deploymentConfig" -}}
{{- $values := deepCopy .Values }}
{{- $data := dict "Values" $values | mustMergeOverwrite (deepCopy .) }}
{{- $config := include "finops-otel-collector.baseConfig" $data | fromYaml }}
{{- if .Values.presets.logsCollection.enabled }}
{{- $config = (include "finops-otel-collector.applyLogsCollectionConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.hostMetrics.enabled }}
{{- $config = (include "finops-otel-collector.applyHostMetricsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.kubeletMetrics.enabled }}
{{- $config = (include "finops-otel-collector.applyKubeletMetricsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.kubernetesAttributes.enabled }}
{{- $config = (include "finops-otel-collector.applyKubernetesAttributesConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.kubernetesEvents.enabled }}
{{- $config = (include "finops-otel-collector.applyKubernetesEventsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- if .Values.presets.clusterMetrics.enabled }}
{{- $config = (include "finops-otel-collector.applyClusterMetricsConfig" (dict "Values" $data "config" $config) | fromYaml) }}
{{- end }}
{{- tpl (toYaml $config) . }}
{{- end }}

{{- define "finops-otel-collector.applyHostMetricsConfig" -}}
{{- $config := mustMergeOverwrite (include "finops-otel-collector.hostMetricsConfig" .Values | fromYaml) .config }}
{{- $_ := set $config.service.pipelines.metrics "receivers" (append $config.service.pipelines.metrics.receivers "hostmetrics" | uniq)  }}
{{- $config | toYaml }}
{{- end }}

{{- define "finops-otel-collector.hostMetricsConfig" -}}
receivers:
  hostmetrics:
    root_path: /hostfs
    collection_interval: 10s
    scrapers:
        cpu:
        load:
        memory:
        disk:
        filesystem:
          exclude_mount_points:
            mount_points:
              - /dev/*
              - /proc/*
              - /sys/*
              - /run/k3s/containerd/*
              - /var/lib/docker/*
              - /var/lib/kubelet/*
              - /snap/*
            match_type: regexp
          exclude_fs_types:
            fs_types:
              - autofs
              - binfmt_misc
              - bpf
              - cgroup2
              - configfs
              - debugfs
              - devpts
              - devtmpfs
              - fusectl
              - hugetlbfs
              - iso9660
              - mqueue
              - nsfs
              - overlay
              - proc
              - procfs
              - pstore
              - rpc_pipefs
              - securityfs
              - selinuxfs
              - squashfs
              - sysfs
              - tracefs
            match_type: strict
        network:
{{- end }}

{{- define "finops-otel-collector.applyClusterMetricsConfig" -}}
{{- $config := mustMergeOverwrite (include "finops-otel-collector.clusterMetricsConfig" .Values | fromYaml) .config }}
{{- $_ := set $config.service.pipelines.metrics "receivers" (append $config.service.pipelines.metrics.receivers "k8s_cluster" | uniq)  }}
{{- $config | toYaml }}
{{- end }}

{{- define "finops-otel-collector.clusterMetricsConfig" -}}
receivers:
  k8s_cluster:
    collection_interval: 10s
{{- end }}

{{- define "finops-otel-collector.applyKubeletMetricsConfig" -}}
{{- $config := mustMergeOverwrite (include "finops-otel-collector.kubeletMetricsConfig" .Values | fromYaml) .config }}
{{- $_ := set $config.service.pipelines.metrics "receivers" (append $config.service.pipelines.metrics.receivers "kubeletstats" | uniq)  }}
{{- $config | toYaml }}
{{- end }}

{{- define "finops-otel-collector.kubeletMetricsConfig" -}}
receivers:
  kubeletstats:
    collection_interval: 20s
    auth_type: "serviceAccount"
    endpoint: "${env:K8S_NODE_NAME}:10250"
{{- end }}

{{- define "finops-otel-collector.applyLogsCollectionConfig" -}}
{{- $config := mustMergeOverwrite (include "finops-otel-collector.logsCollectionConfig" .Values | fromYaml) .config }}
{{- $_ := set $config.service.pipelines.logs "receivers" (append $config.service.pipelines.logs.receivers "filelog" | uniq)  }}
{{- if .Values.Values.presets.logsCollection.storeCheckpoints}}
{{- $_ := set $config.service "extensions" (append $config.service.extensions "file_storage" | uniq)  }}
{{- end }}
{{- $config | toYaml }}
{{- end }}

{{- define "finops-otel-collector.logsCollectionConfig" -}}
{{- if .Values.presets.logsCollection.storeCheckpoints }}
extensions:
  file_storage:
    directory: /var/lib/otelcol
{{- end }}
receivers:
  filelog:
    include: [ /var/log/pods/*/*/*.log ]
    {{- if .Values.presets.logsCollection.includeCollectorLogs }}
    exclude: []
    {{- else }}
    # Exclude collector container's logs. The file format is /var/log/pods/<namespace_name>_<pod_name>_<pod_uid>/<container_name>/<run_id>.log
    exclude: [ /var/log/pods/{{ .Release.Namespace }}_{{ include "finops-otel-collector.fullname" . }}*_*/{{ include "finops-otel-collector.lowercase_chartname" . }}/*.log ]
    {{- end }}
    start_at: end
    {{- if .Values.presets.logsCollection.storeCheckpoints}}
    storage: file_storage
    {{- end }}
    include_file_path: true
    include_file_name: false
    operators:
      # Find out which format is used by kubernetes
      - type: router
        id: get-format
        routes:
          - output: parser-docker
            expr: 'body matches "^\\{"'
          - output: parser-crio
            expr: 'body matches "^[^ Z]+ "'
          - output: parser-containerd
            expr: 'body matches "^[^ Z]+Z"'
      # Parse CRI-O format
      - type: regex_parser
        id: parser-crio
        regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout_type: gotime
          layout: '2006-01-02T15:04:05.999999999Z07:00'
      - type: recombine
        id: crio-recombine
        output: extract_metadata_from_filepath
        combine_field: attributes.log
        source_identifier: attributes["log.file.path"]
        is_last_entry: "attributes.logtag == 'F'"
        combine_with: ""
        max_log_size: {{ $.Values.presets.logsCollection.maxRecombineLogSize }}
      # Parse CRI-Containerd format
      - type: regex_parser
        id: parser-containerd
        regex: '^(?P<time>[^ ^Z]+Z) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      - type: recombine
        id: containerd-recombine
        output: extract_metadata_from_filepath
        combine_field: attributes.log
        source_identifier: attributes["log.file.path"]
        is_last_entry: "attributes.logtag == 'F'"
        combine_with: ""
        max_log_size: {{ $.Values.presets.logsCollection.maxRecombineLogSize }}
      # Parse Docker format
      - type: json_parser
        id: parser-docker
        output: extract_metadata_from_filepath
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      # Extract metadata from file path
      - type: regex_parser
        id: extract_metadata_from_filepath
        regex: '^.*\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[a-f0-9\-]+)\/(?P<container_name>[^\._]+)\/(?P<restart_count>\d+)\.log$'
        parse_from: attributes["log.file.path"]
      # Rename attributes
      - type: move
        from: attributes.stream
        to: attributes["log.iostream"]
      - type: move
        from: attributes.container_name
        to: resource["k8s.container.name"]
      - type: move
        from: attributes.namespace
        to: resource["k8s.namespace.name"]
      - type: move
        from: attributes.pod_name
        to: resource["k8s.pod.name"]
      - type: move
        from: attributes.restart_count
        to: resource["k8s.container.restart_count"]
      - type: move
        from: attributes.uid
        to: resource["k8s.pod.uid"]
      # Clean up log body
      - type: move
        from: attributes.log
        to: body
{{- end }}

{{- define "finops-otel-collector.applyKubernetesAttributesConfig" -}}
{{- $config := mustMergeOverwrite (include "finops-otel-collector.kubernetesAttributesConfig" .Values | fromYaml) .config }}
{{- if and ($config.service.pipelines.logs) (not (has "k8sattributes" $config.service.pipelines.logs.processors)) }}
{{- $_ := set $config.service.pipelines.logs "processors" (prepend $config.service.pipelines.logs.processors "k8sattributes" | uniq)  }}
{{- end }}
{{- if and ($config.service.pipelines.metrics) (not (has "k8sattributes" $config.service.pipelines.metrics.processors)) }}
{{- $_ := set $config.service.pipelines.metrics "processors" (prepend $config.service.pipelines.metrics.processors "k8sattributes" | uniq)  }}
{{- end }}
{{- if and ($config.service.pipelines.traces) (not (has "k8sattributes" $config.service.pipelines.traces.processors)) }}
{{- $_ := set $config.service.pipelines.traces "processors" (prepend $config.service.pipelines.traces.processors "k8sattributes" | uniq)  }}
{{- end }}
{{- $config | toYaml }}
{{- end }}

{{- define "finops-otel-collector.kubernetesAttributesConfig" -}}
processors:
  k8sattributes:
  {{- if eq .Values.mode "daemonset" }}
    filter:
      node_from_env_var: K8S_NODE_NAME
  {{- end }}
    passthrough: false
    pod_association:
    - sources:
      - from: resource_attribute
        name: k8s.pod.ip
    - sources:
      - from: resource_attribute
        name: k8s.pod.uid
    - sources:
      - from: connection
    extract:
      metadata:
        - "k8s.namespace.name"
        - "k8s.deployment.name"
        - "k8s.statefulset.name"
        - "k8s.daemonset.name"
        - "k8s.cronjob.name"
        - "k8s.job.name"
        - "k8s.node.name"
        - "k8s.pod.name"
        - "k8s.pod.uid"
        - "k8s.pod.start_time"
      {{- if .Values.presets.kubernetesAttributes.extractAllPodLabels }}
      labels:
        - tag_name: $$1
          key_regex: (.*)
          from: pod
      {{- end }}
      {{- if .Values.presets.kubernetesAttributes.extractAllPodAnnotations }}
      annotations:
        - tag_name: $$1
          key_regex: (.*)
          from: pod
      {{- end }}
{{- end }}

{{/* Build the list of port for service */}}
{{- define "finops-otel-collector.servicePortsConfig" -}}
{{- $ports := deepCopy .Values.ports }}
{{- range $key, $port := $ports }}
{{- if $port.enabled }}
- name: {{ $key }}
  port: {{ $port.servicePort }}
  targetPort: {{ $port.containerPort }}
  protocol: {{ $port.protocol }}
  {{- if $port.appProtocol }}
  appProtocol: {{ $port.appProtocol }}
  {{- end }}
{{- if $port.nodePort }}
  nodePort: {{ $port.nodePort }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* Build the list of port for pod */}}
{{- define "finops-otel-collector.podPortsConfig" -}}
{{- $ports := deepCopy .Values.ports }}
{{- range $key, $port := $ports }}
{{- if $port.enabled }}
- name: {{ $key }}
  containerPort: {{ $port.containerPort }}
  protocol: {{ $port.protocol }}
  {{- if and $.isAgent $port.hostPort }}
  hostPort: {{ $port.hostPort }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "finops-otel-collector.applyKubernetesEventsConfig" -}}
{{- $config := mustMergeOverwrite (include "finops-otel-collector.kubernetesEventsConfig" .Values | fromYaml) .config }}
{{- $_ := set $config.service.pipelines.logs "receivers" (append $config.service.pipelines.logs.receivers "k8sobjects" | uniq)  }}
{{- $config | toYaml }}
{{- end }}

{{- define "finops-otel-collector.kubernetesEventsConfig" -}}
receivers:
  k8sobjects:
    objects:
      - name: events
        mode: "watch"
        group: "events.k8s.io"
        exclude_watch_type:
          - "DELETED"
{{- end }}
