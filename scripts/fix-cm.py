import json, yaml, sys

with open(sys.argv[1]) as f:
    cm = json.load(f)

relay = yaml.safe_load(cm['data']['relay'])

statements = [
    # Resource attributes for count connector
    'set(resource.attributes["audit.service_name"], "KubernetesEventNotify")',
    'set(resource.attributes["audit.audit_event"], "POD_CRASH_LOOP") where attributes["k8s.event.reason"] == "BackOff"',
    'set(resource.attributes["audit.audit_event"], "POD_OOM_KILLED") where attributes["k8s.event.reason"] == "OOMKilled"',
    'set(resource.attributes["audit.audit_event"], "POD_CONTAINER_FAILED") where attributes["k8s.event.reason"] == "Failed"',
    'set(resource.attributes["audit.audit_event"], "POD_IMAGE_PULL_FAILED") where attributes["k8s.event.reason"] == "ErrImagePull"',
    'set(resource.attributes["audit.audit_event"], "POD_IMAGE_PULL_BACKOFF") where attributes["k8s.event.reason"] == "ImagePullBackOff"',
    'set(resource.attributes["audit.audit_event"], "POD_SCHEDULING_FAILED") where attributes["k8s.event.reason"] == "FailedScheduling"',
    'set(resource.attributes["audit.audit_event"], "POD_VOLUME_MOUNT_FAILED") where attributes["k8s.event.reason"] == "FailedMount"',
    'set(resource.attributes["audit.audit_event"], "POD_VOLUME_ATTACH_FAILED") where attributes["k8s.event.reason"] == "FailedAttachVolume"',
    'set(resource.attributes["audit.audit_status"], "FAILURE")',
    'set(resource.attributes["audit.app_id"], resource.attributes["app_id"])',
    'set(resource.attributes["audit.app_type"], resource.attributes["app_type"])',
    'set(resource.attributes["audit.dataplane_id"], resource.attributes["dataplane_id"])',
    'set(resource.attributes["audit.instance"], resource.attributes["k8s.object.name"])',
    'set(resource.attributes["audit.app_instance"], resource.attributes["k8s.object.name"])',
    'set(resource.attributes["audit.severity"], "warning")',
    'set(resource.attributes["audit.severity"], "critical") where attributes["k8s.event.reason"] == "BackOff" or attributes["k8s.event.reason"] == "OOMKilled" or attributes["k8s.event.reason"] == "ErrImagePull" or attributes["k8s.event.reason"] == "ImagePullBackOff" or attributes["k8s.event.reason"] == "FailedScheduling" or attributes["k8s.event.reason"] == "Failed"',
    'set(resource.attributes["audit.scope"], "DP") where resource.attributes["workload_type"] == "infra"',
    'set(resource.attributes["audit.scope"], "CAP") where resource.attributes["workload_type"] == "capability-service"',
    'set(resource.attributes["audit.scope"], "APP") where resource.attributes["workload_type"] == "user-app"',
    # Body: only ES-mapped fields
    'set(cache["trans_desp"], Concat([attributes["k8s.event.reason"], body], ": "))',
    'set(cache["trans_id"], UUID())',
    'set(cache["service_name"], "KubernetesEventNotify")',
    'set(cache["trans_status"], "FAILURE")',
    'set(cache["trans_state"], "POD_CRASH_LOOP") where attributes["k8s.event.reason"] == "BackOff"',
    'set(cache["trans_state"], "POD_OOM_KILLED") where attributes["k8s.event.reason"] == "OOMKilled"',
    'set(cache["trans_state"], "POD_CONTAINER_FAILED") where attributes["k8s.event.reason"] == "Failed"',
    'set(cache["trans_state"], "POD_IMAGE_PULL_FAILED") where attributes["k8s.event.reason"] == "ErrImagePull"',
    'set(cache["trans_state"], "POD_IMAGE_PULL_BACKOFF") where attributes["k8s.event.reason"] == "ImagePullBackOff"',
    'set(cache["trans_state"], "POD_SCHEDULING_FAILED") where attributes["k8s.event.reason"] == "FailedScheduling"',
    'set(cache["trans_state"], "POD_VOLUME_MOUNT_FAILED") where attributes["k8s.event.reason"] == "FailedMount"',
    'set(cache["trans_state"], "POD_VOLUME_ATTACH_FAILED") where attributes["k8s.event.reason"] == "FailedAttachVolume"',
    'set(cache["trans_source"], resource.attributes["k8s.object.name"])',
    'set(cache["trans_destination"], attributes["k8s.namespace.name"])',
    'set(cache["trans_ts"], FormatTime(log.time, "%Y-%m-%dT%H:%M:%S.%LZ"))',
    'set(cache["create_ts"], FormatTime(log.time, "%Y-%m-%dT%H:%M:%S.%LZ"))',
    'set(cache["user_trans_id"], resource.attributes["dataplane_id"]) where resource.attributes["workload_type"] == "infra"',
    'set(cache["user_trans_id"], resource.attributes["capability_instance_id"]) where resource.attributes["workload_type"] == "capability-service"',
    'set(cache["user_trans_id"], resource.attributes["app_id"]) where resource.attributes["workload_type"] == "user-app"',
    'set(cache["user_id"], "System")',
    'set(cache["entry_id"], "")',
    'set(cache["parent_id"], "")',
    # Build extra_props entries (matching Go collectExtraProps field names)
    'set(cache["ep0"]["prop_name"], "Scope")',
    'set(cache["ep0"]["prop_value"], resource.attributes["audit.scope"])',
    'set(cache["ep1"]["prop_name"], "UserId")',
    'set(cache["ep1"]["prop_value"], "System")',
    'set(cache["ep2"]["prop_name"], "DataPlaneId")',
    'set(cache["ep2"]["prop_value"], resource.attributes["dataplane_id"])',
    'set(cache["ep2"]["prop_value"], "") where resource.attributes["dataplane_id"] == nil',
    'set(cache["ep3"]["prop_name"], "DataPlaneType")',
    'set(cache["ep3"]["prop_value"], "k8s")',
    'set(cache["ep4"]["prop_name"], "CapabilityInstanceId")',
    'set(cache["ep4"]["prop_value"], resource.attributes["capability_instance_id"])',
    'set(cache["ep4"]["prop_value"], "") where resource.attributes["capability_instance_id"] == nil',
    'set(cache["ep5"]["prop_name"], "CapabilityName")',
    'set(cache["ep5"]["prop_value"], resource.attributes["app_type"])',
    'set(cache["ep5"]["prop_value"], "") where resource.attributes["app_type"] == nil',
    'set(cache["ep6"]["prop_name"], "AppId")',
    'set(cache["ep6"]["prop_value"], resource.attributes["app_id"])',
    'set(cache["ep6"]["prop_value"], "") where resource.attributes["app_id"] == nil',
    'set(cache["ep7"]["prop_name"], "AppName")',
    'set(cache["ep7"]["prop_value"], resource.attributes["app_name"])',
    'set(cache["ep7"]["prop_value"], "") where resource.attributes["app_name"] == nil',
    'set(cache["ep8"]["prop_name"], "k8s.event.reason")',
    'set(cache["ep8"]["prop_value"], attributes["k8s.event.reason"])',
    'set(cache["ep9"]["prop_name"], "k8s.event.count")',
    'set(cache["ep9"]["prop_value"], attributes["k8s.event.count"])',
    'set(cache["ep10"]["prop_name"], "k8s.object.kind")',
    'set(cache["ep10"]["prop_value"], resource.attributes["k8s.object.kind"])',
    'set(cache["ep11"]["prop_name"], "severity")',
    'set(cache["ep11"]["prop_value"], resource.attributes["audit.severity"])',
    # Set body from cache, then remove epN keys
    'set(body, cache)',
]

# Delete all epN keys from body
for i in range(12):
    statements.append(f'delete_key(body, "ep{i}")')

# Construct extra_props nested array
statements.append('append(body["extra_props"], values = ["el0", "el1", "el2", "el3", "el4", "el5", "el6", "el7", "el8", "el9", "el10", "el11"])')
for i in range(12):
    statements.append(f'set(body["extra_props"][{i}], cache["ep{i}"])')

relay['processors']['transform/audit-body'] = {
    'error_mode': 'ignore',
    'log_statements': [{
        'context': 'log',
        'statements': statements,
    }]
}

cm['data']['relay'] = yaml.dump(relay, default_flow_style=False)

for key in ['managedFields', 'resourceVersion', 'uid', 'creationTimestamp']:
    cm['metadata'].pop(key, None)
cm.pop('status', None)
cm['metadata'].get('annotations', {}).pop('kubectl.kubernetes.io/last-applied-configuration', None)

with open(sys.argv[2], 'w') as f:
    json.dump(cm, f)

print('Done')
