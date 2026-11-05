<!--
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
-->

# tibco-cp-mft

TIBCO Control Plane chart for the MFT capability. It is an umbrella that bundles the
Control-Plane-side MFT components; today that is the [`mft-webserver`](charts/mft-webserver)
sub-chart (the Koa API + single-spa UIs, image `tp-mft-webserver`), exposed to the CP shell
via a `TibcoRoute` under `/cp/mft`. The webserver proxies to the on-prem MFT adapter on the
Data Plane (see the `dp-mft-adapter` chart) and persists instances in the shared CP
`v3_resource_instances` store (resource type `MFTSERVER`).
