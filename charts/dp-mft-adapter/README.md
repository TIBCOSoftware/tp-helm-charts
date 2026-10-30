<!--
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
-->

# dp-mft-adapter

TIBCO Platform bare-metal Data Plane capability chart for the MFT adapter. It deploys the
adapter as a Kubernetes Deployment + Service in the Data Plane namespace. The adapter is
reached only over the CP -> DP proxy (not publicly exposed) and proxies MFT REST calls to
the on-prem MFT command center.
