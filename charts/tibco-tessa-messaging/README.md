# CP Install Chart: tibco-tessa-messaging
This chart is an example of how to deploy the preview EMS-MCP server in a platform context.

## Installing INFRA chart recipe package in CP
- In the CP, the chart `tibco-tessa-messaging` will install the infra EMSMCP recipe package for installing `msg-tessa-ems-mcp` into Tessa EMS enabled dataplanes.
- Only values required are the standard `global.cp...` settings used for installing `tibco-cp-messaging` (or `tibco-cp-base`)
```bash
helm get values tibco-cp-messaging | \
helm upgrade --install -f - tibco-tessa-messaging tp-helm-charts/tibco-tessa-messaging --version=1.21.20
```
- current version= 1.21.5

## Dataplane EMS-MCP server PLATFORM chart
- `msg-tessa-ems-mcp`, version=`1.21.^` (1.21.5 or later)
- StatefulSet: tp-msg-emsmcp (replicas=1)
- Ingress: `ingress/tp-msg-emsmcp-emsmcp`
- Default affinity - same node as tp-msg-gateway-0 pod
- Authentication: via `svc/tp-msg-gateway` api.
- Only values required are the standard `global.cp...` settings injected on provisioning requests.
- Local DP hostport is: `http://tp-msg-emsmcp:8080`
- MCP server user/password from K8s secret/tp-msggw-mcp-credentials (created by msg-gateway if missing)

### Manual DP helm install
```
export NS=<your-target-namespace>
gwRelease=$(kubectl get -n=$NS sts/tp-msg-gateway -o=jsonpath='{.metadata.labels.tib-dp-release}')
helm get values -n=$NS $gwRelease | helm upgrade --install -f - -n=$NS tp-msg-emsmcp tp-helm-charts/msg-tessa-ems-mcp --version=1.21.^

```

## NOTE: Allow vscode MCP urls with self-signed certificates
- required to be set before starting vscode (added to /usr/local/bin/code script)
```bash
export NODE_TLS_REJECT_UNAUTHORIZED=0
```
## Example vscode mcp.json workspace file
```json
{
    "servers": {
        "ems-mcp-server": {
            "type": "http",
            "url": "https://dev.cp1-my.msgdp-dev4.maas-dev.dataplanes.pro/cp/api/v1/msgdp/d82ac9jtfr8s73dcbrpg/tessa/ems/mcp",
            "headers": {
                "Authorization": "Bearer CIC~jzk1mNKt3ulK_FlQXtRk16vh"
            }
        }
    }
}
```
## Example vscode prompts
- `how many of my EMS servers are healthy`
- `how many connections do I have to my EMS servers`

Response: Ran `tibco_ems_get_server_status` 
Completed with input: {
  "query": "{ servers { name serverGroup statistics { connectionCount clientConnectionCount adminConnectionCount } } }",
  "serverGroups": [
    "ems115-dev",
    "ems17-dev",
    "nextup-toy"
  ]
}

**12 total connections** across all 3 EMS servers:

| Server | Server Group | Total | Client | Admin |
|--------|-------------|-------|--------|-------|
| nextup-ems | nextup-toy | 4 | 2 | 2 |
| ems115-ems | ems115-dev | 4 | 2 | 2 |
| ems17-ems | ems17-dev | 4 | 2 | 2 |

## Talking to an EMS-MCP via CP routing 
```bash
export myUrl="$cpHostname/cp/api/v1/msgdp/$myDataplane/tessa/ems/mcp"
curl -k -i -X POST -H "Authorization: Bearer $myCicToken"  -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}}}' "$myUrl"
```
## Talking to an EMS-MCP from a Control-plane service
```bash
export myJWT=...yours-here...
export myCicToken=CIC~VIfVE8FdYNMgscGhs3q9JMwm
export myDataplane=d5e8bgduu3dc738eaf4g
export msgDpPath="http://dp-proxy.cp1-ns.svc.cluster.local/v1/proxy/$myDataplane/tibco/agent/msg"
export tessa="/tessa/ems"
curl -i -X POST -H "X-Atmosphere-Token: $myJWT" -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}}}' "$msgDpPath${tessa}/mcp"

export myDataplane="d5e8bgduu3dc738eaf4g"
export mcpDpBase="http://dp-proxy.cp1-ns.svc.cluster.local/v1/proxy/$myDataplane"
export mcpDpRoute="/tibco/agent/msg/tessa/ems"
```
- Example output
```
HTTP/1.1 200 OK
Content-Length: 255
Content-Type: application/json
Date: Tue, 12 May 2026 21:12:33 GMT
Mcp-Session-Id: mcp-session-fb9e9eba-dad0-4854-b30c-4529f9104184

{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"prompts":{"listChanged":true},"resources":{"subscribe":true,"listChanged":true},"tools":{"listChanged":true}},"serverInfo":{"name":"TIBCO EMS MCP Server","version":"4.0"}}}
```

## Sample Talking to an EMS-MCP via CP CIC-token & TibcoRoute object
```bash
export myCicToken=CIC~...fixme..
export cpHostname="https://neworg.cp1-my.vc-kevin2.emsapp4.na.tibco.com"
export myDataplane=d5e8bgduu3dc738eaf4g

export msgDpPath="$cpHostname/cp/api/v1/msgdp/$myDataplane"
export tessa="/tessa/ems"
curl -k -i -X POST -H "Authorization: Bearer $myCicToken" -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}}}' "$msgDpPath${tessa}/mcp"

```
## TibcoRoute object for vscode access
- The CP chart `tibco-tessa-messaging` installs a K8s CR `TibcoRoute/tp-cp-msg-tessa-emsmcp` , that uses the dp-proxy and the dataplaneID to route requests to a DP tessa-ems-mcp server.
- This route is secured via CIC OAuth Token

## Trouble-shooting
- VScode when URL uses self-signed certificates
    - Add settings.json
    ```json
    {
      "http.proxyStrictSSL": false
    }
    ```
    - set node option in shell before starting vscode
    ```
    NODE_TLS_REJECT_UNAUTHORIZED=0
    ```
