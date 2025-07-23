# Chart msg-gateway-tp
This chart is a transition helper until we have fully rolled out `tp-msg-gateway` to K8DPs.  This chart will auto-register all the K8-EMS instances it finds in its local K8DP on startup (or pod restart).
- The Ingress paths are setup to mimic what we use with a CTDP tp-msg-gateway.
- The idea being that Gems can use common logic for accessing a K8DP provisioned EMS or a CT registered EMS
- In the future a K8DP version of the `hawk-console` chart will be deployed as a shared `INFRA` dependency chart when `EMS` is provisioned into a K8DP.
## Installing manually using `tp-helm-charts` repo base chart
* Using a DP kubeconfig (and namespace options if default is not set to K8DP)
* assuming helm repo tp-helm-charts is added.
```bash
helm repo update
helm upgrade --install k8-gateway tp-helm-charts/msg-gateway-tp --version=1.9.13
```
## Checking K8DP registrations
* With a K8DP kubeconfig
```bash
kubectl exec -ti tp-msg-gateway-0 -- bash
source /logs/boot/plt-functions.sh
restdHealth
```
* Sample health output
```json
{
  "errors": [
    {
      "detail": "EMS monitor URL could not be reached for liveness check: dial tcp [::1]:9010: connect: connection refused: Not available",
      "server_group": "default",
      "server_role": "primary",
      "status": 503,
      "type": "Not available"
    }
  ],
  "healths": [
    {
      "live": true,
      "ready": false,
      "server_role": "d-apple-ems-0.d-apple-ems-pods.vdp.svc:9011",
      "server_group": "d-apple"
    },
    {
      "live": true,
      "ready": true,
      "server_role": "d-apple-ems-1.d-apple-ems-pods.vdp.svc:9011",
      "server_group": "d-apple"
    },
    {
      "live": true,
      "ready": false,
      "server_role": "d-apple-ems-2.d-apple-ems-pods.vdp.svc:9011",
      "server_group": "d-apple"
    }
  ]
}
```
## PUSHING A New featured chart build
* Update version.txt with an updated build suffix (lexically higher)
`eg. 1.8.0.10-k8gateway-01`
* Do a chart PR-branch vbuild (no tagging) via:
```bash
cd $build
cmake $source
make all
./jenkins/promote_vbuild.in.sh -SKIP_TAGS=true -SKIP_CHARTS=false -SKIP_IMAGES=false
```
* Then open the PR from PR-branch to Feature base branch
* add the `chart-build` label  to the PR 
* Wait for the chart to build and publish
* Close the PR, deleting unneeded branches
