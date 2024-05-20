# dp-config-aws helm chart
[dp-config-aws](charts/dp-config-aws) is used to create
* external ingress for DP/CP cluster
* internal ingress for DP/CP cluster
* storage class
* crossplane installation
# crossplane-components helm chart
[crossplane-components](charts/crossplane-components/) subchart used to
* install providers
* install provider-configs
* create composite resource definitions (XRDs) and compositions
* create claims