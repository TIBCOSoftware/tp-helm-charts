[dp-configure-namespace](charts/dp-configure-namespace) is used to create the following objects in dataplane namespace
* ClusterRoles
* ClusterRoleBinding
* ServiceAccount
* RoleBinding
* NetworkPolicies

# Use-case 1

Customer has created new primary namespace and applied the Tibco platform dataPlane label.
Customer now wants to create new service-account, cluster-role, cluster-role-binding, role-binding & (optional) network policies.

## Release Namespace and Primary Namespace
.Release.Namespace is same as .Values.global.tibco.primaryNamespaceName.
So, service-account is created in this namespace, which will be referred in the subsequent application namespace(s) configuration.

## Sample values
global:
  tibco:
    dataPlaneId: "abcd" # Mandatory
    primaryNamespaceName: "dp-namespace" # Mandatory
    serviceAccount: "sa" # Mandatory

createServiceAccount: true # Default true

createNetworkPolicy: false # Default false, set to true to enable network policies
nodeCidrIpBlock: "" # If createNetworkPolicy above is true, node CIDR IP block is required
podCidrIpBlock: "" # If createNetworkPolicy above is true & pod CIDR IP block is different from nodeCidrIpBlock, then podCidrIpBlock is required. Otherwise, it will be set equal to nodeCidrIpBlock

# Use-case 2

Customer has created new application namespace and applied the Tibco platform dataPlane labels.
The cluster-roles, cluster-role-binidng are present and service-account in primary namespace is to be used.
To enable application deployment Customer needs to create role-binding and network policies in the new namespace.

## Release Namespace and Primary Namespace
.Release.Namespace is NOT same as .Values.global.tibco.primaryNamespaceName.
So, only role-binding and (optional) network policies are created in this namespace.
Service Account is used from the primaryNamespaceName.

## Sample values
global:
  tibco:
    dataPlaneId: "abcd" # Mandatory
    primaryNamespaceName: "dp-namespace" # Mandatory
    serviceAccount: "sa" # Mandatory

createNetworkPolicy: false # Default false, set to true to enable network policies
nodeCidrIpBlock: "" # If createNetworkPolicy above is true, node CIDR IP block is required
podCidrIpBlock: "" # If createNetworkPolicy above is true & pod CIDR IP block is different from nodeCidrIpBlock, then podCidrIpBlock is required. Otherwise, it will be set equal to nodeCidrIpBlock
