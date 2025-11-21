/**
 * Copyright (c) 2020-2025. Cloud Software Group, Inc.
 * All Rights Reserved. Confidential & Proprietary.
 */

CREATE SCHEMA IF NOT EXISTS redtail_ct_info
AUTHORIZATION :AUTHUSER;


SET search_path TO redtail_ct_info;


CREATE TABLE IF NOT EXISTS SCHEMA_VERSION (
	ID SERIAL PRIMARY KEY,
	VERSION INTEGER NOT NULL,

	CONSTRAINT SCHEMA_VERSION_UNIQUE_CONSTRAINT UNIQUE (VERSION)
);

INSERT INTO SCHEMA_VERSION (VERSION) VALUES (1) ON CONFLICT DO NOTHING;
--
-- Table structure for table `data_plane_details`
--
CREATE TABLE IF NOT EXISTS data_plane_details(
     id SERIAL PRIMARY KEY,
     subscriber_id VARCHAR(50) NOT NULL,
     data_plane_id VARCHAR(50) NOT NULL,
     hawk_console_service VARCHAR(200) NOT NULL,
     ct_auth_token VARCHAR(100) NOT NULL,
     UNIQUE (subscriber_id, data_plane_id)
);

CREATE TABLE IF NOT EXISTS redtail_ct_info.infra_datamodel(
     id serial PRIMARY KEY,
     name varchar(200) NOT NULL,
     datamodel_config json,
     UNIQUE (name)
);


INSERT INTO redtail_ct_info.infra_datamodel(name, datamodel_config) VALUES('OI_Prometheus_Targets','{
  "version": "1",
  "name": "OI_Prometheus_Targets",
  "active": "true",
  "createdBy": "System",
  "createdAt": "",
  "lastUpdated": "",
  "sourceFilter": "",
  "parsingRules": [],
  "columns": [
    {"name": "ScrapePool", "type": "STRING"},
    {"name": "Endpoint", "type": "STRING"},
    {"name": "State", "type": "STRING"},
    {"name": "Labels", "type": "STRING"},
    {"name": "Last_Scrape", "type": "STRING"},
    {"name": "Scrape_Duration", "type": "STRING"},
    {"name": "Error", "type": "STRING"},
    {"name": "sys_eventTime", "type": "TIMESTAMP"}

  ],
  "groupName": "System"
}') ON CONFLICT DO NOTHING;

INSERT INTO redtail_ct_info.infra_datamodel(name, datamodel_config) VALUES('OI_Prometheus_Flags','{
  "version": "1",
  "name": "OI_Prometheus_Flags",
  "active": "true",
  "createdBy": "System",
  "createdAt": "",
  "lastUpdated": "",
  "sourceFilter": "",
  "parsingRules": [],
  "columns": [
    {"name": "Name", "type": "STRING"},
    {"name": "Value", "type": "STRING"},
    {"name": "sys_eventTime", "type": "TIMESTAMP"}

  ],
  "groupName": "System"
}') ON CONFLICT DO NOTHING;

INSERT INTO redtail_ct_info.infra_datamodel(name, datamodel_config) VALUES('OI_Prometheus_Runtime','{
  "version": "1",
  "name": "OI_Prometheus_Runtime",
  "active": "true",
  "createdBy": "System",
  "createdAt": "",
  "lastUpdated": "",
  "sourceFilter": "",
  "parsingRules": [],
  "columns": [
    {"name": "Name", "type": "STRING"},
    {"name": "Value", "type": "STRING"},
    {"name": "sys_eventTime", "type": "TIMESTAMP"}

  ],
  "groupName": "System"
}') ON CONFLICT DO NOTHING;

INSERT INTO redtail_ct_info.infra_datamodel(name, datamodel_config) VALUES('OI_Prometheus_Build','{
  "version": "1",
  "name": "OI_Prometheus_Build",
  "active": "true",
  "createdBy": "System",
  "createdAt": "",
  "lastUpdated": "",
  "sourceFilter": "",
  "parsingRules": [],
  "columns": [
    {"name": "Name", "type": "STRING"},
    {"name": "Value", "type": "STRING"},
    {"name": "sys_eventTime", "type": "TIMESTAMP"}
  ],
  "groupName": "System"
}') ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS redtail_ct_info.datamodel(
                                                        id serial PRIMARY KEY,
                                                        name varchar(200) NOT NULL,
    datamodel_config json,
    UNIQUE (name)
    );

INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatus_uptime', '{"name":"TS_hawk_adr3sap_getstatus_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776145,"createdAt":1695375776145,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatus_new_errors', '{"name":"TS_hawk_adr3sap_getstatus_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776155,"createdAt":1695375776155,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatus_messages_received', '{"name":"TS_hawk_adr3sap_getstatus_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776153,"createdAt":1695375776153,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatus_messages_sent', '{"name":"TS_hawk_adr3sap_getstatus_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776154,"createdAt":1695375776154,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatus_total_errors', '{"name":"TS_hawk_adr3sap_getstatus_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776156,"createdAt":1695375776156,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getadapterserviceinformation_line', '{"name":"TS_hawk_adr3sap_getadapterserviceinformation_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776520,"createdAt":1695375776520,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getadapterserviceinformationext_number_of_messages', '{"name":"TS_hawk_adr3sap_getadapterserviceinformationext_number_of_messages","description":"number of rv messages published/received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776847,"createdAt":1695375776847,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getadapterserviceinformationext_line', '{"name":"TS_hawk_adr3sap_getadapterserviceinformationext_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375776846,"createdAt":1695375776846,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getrvqueueinfo_tibrvqueue_size', '{"name":"TS_hawk_adr3sap_getrvqueueinfo_tibrvqueue_size","description":"Event Count in session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375777250,"createdAt":1695375777250,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getrvqueueinfo_tibrvqueue_priority', '{"name":"TS_hawk_adr3sap_getrvqueueinfo_tibrvqueue_priority","description":"Priority of session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375777250,"createdAt":1695375777250,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_gethostinformation_hkinfo', '{"name":"TS_hawk_adr3sap_gethostinformation_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"value","computed":false,"expression":"$value","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375777513,"createdAt":1695375777513,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getcomponents_hkinfo', '{"name":"TS_hawk_adr3sap_getcomponents_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"component_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"description","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"component_type","type":"STRING"},{"name":"protocol","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"component_name","computed":false,"expression":"$component_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"description","computed":false,"expression":"$description","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"component_type","computed":false,"expression":"$component_type","type":"STRING"},{"name":"protocol","computed":false,"expression":"$protocol","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375777786,"createdAt":1695375777786,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getconfig_hkinfo', '{"name":"TS_hawk_adr3sap_getconfig_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"command","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"configuration_url","type":"STRING"},{"name":"repository_connection","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"command","computed":false,"expression":"$command","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"configuration_url","computed":false,"expression":"$configuration_url","type":"STRING"},{"name":"repository_connection","computed":false,"expression":"$repository_connection","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778142,"createdAt":1695375778142,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatusext_process_id', '{"name":"TS_hawk_adr3sap_getstatusext_process_id","description":"Process ID set by adapter","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778506,"createdAt":1695375778506,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatusext_messages_received', '{"name":"TS_hawk_adr3sap_getstatusext_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778503,"createdAt":1695375778503,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatusext_messages_sent', '{"name":"TS_hawk_adr3sap_getstatusext_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778504,"createdAt":1695375778504,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatusext_new_errors', '{"name":"TS_hawk_adr3sap_getstatusext_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778504,"createdAt":1695375778504,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatusext_uptime', '{"name":"TS_hawk_adr3sap_getstatusext_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778503,"createdAt":1695375778503,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adr3sap_getstatusext_total_errors', '{"name":"TS_hawk_adr3sap_getstatusext_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778505,"createdAt":1695375778505,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getcomponents_hkinfo', '{"name":"TS_hawk_adfiles_getcomponents_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"component_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"description","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"component_type","type":"STRING"},{"name":"protocol","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"component_name","computed":false,"expression":"$component_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"description","computed":false,"expression":"$description","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"component_type","computed":false,"expression":"$component_type","type":"STRING"},{"name":"protocol","computed":false,"expression":"$protocol","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375778771,"createdAt":1695375778771,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getadapterserviceinformation_line', '{"name":"TS_hawk_adfiles_getadapterserviceinformation_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779007,"createdAt":1695375779007,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatusext_messages_received', '{"name":"TS_hawk_adfiles_getstatusext_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779260,"createdAt":1695375779260,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatusext_messages_sent', '{"name":"TS_hawk_adfiles_getstatusext_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779261,"createdAt":1695375779261,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatusext_process_id', '{"name":"TS_hawk_adfiles_getstatusext_process_id","description":"Process ID set by adapter","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779263,"createdAt":1695375779263,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatusext_new_errors', '{"name":"TS_hawk_adfiles_getstatusext_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779261,"createdAt":1695375779261,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatusext_total_errors', '{"name":"TS_hawk_adfiles_getstatusext_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779262,"createdAt":1695375779262,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatusext_uptime', '{"name":"TS_hawk_adfiles_getstatusext_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779260,"createdAt":1695375779260,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getconfig_hkinfo', '{"name":"TS_hawk_adfiles_getconfig_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"command","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"configuration_url","type":"STRING"},{"name":"repository_connection","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"command","computed":false,"expression":"$command","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"configuration_url","computed":false,"expression":"$configuration_url","type":"STRING"},{"name":"repository_connection","computed":false,"expression":"$repository_connection","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779505,"createdAt":1695375779505,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getadapterserviceinformationext_line', '{"name":"TS_hawk_adfiles_getadapterserviceinformationext_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779732,"createdAt":1695375779732,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getadapterserviceinformationext_number_of_messages', '{"name":"TS_hawk_adfiles_getadapterserviceinformationext_number_of_messages","description":"number of rv messages published/received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779733,"createdAt":1695375779733,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_gethostinformation_hkinfo', '{"name":"TS_hawk_adfiles_gethostinformation_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"value","computed":false,"expression":"$value","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375779965,"createdAt":1695375779965,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatus_total_errors', '{"name":"TS_hawk_adfiles_getstatus_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780195,"createdAt":1695375780195,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatus_new_errors', '{"name":"TS_hawk_adfiles_getstatus_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780194,"createdAt":1695375780194,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatus_uptime', '{"name":"TS_hawk_adfiles_getstatus_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780193,"createdAt":1695375780193,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatus_messages_sent', '{"name":"TS_hawk_adfiles_getstatus_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780194,"createdAt":1695375780194,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getstatus_messages_received', '{"name":"TS_hawk_adfiles_getstatus_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780193,"createdAt":1695375780193,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getrvqueueinfo_tibrvqueue_priority', '{"name":"TS_hawk_adfiles_getrvqueueinfo_tibrvqueue_priority","description":"Priority of session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780424,"createdAt":1695375780424,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adfiles_getrvqueueinfo_tibrvqueue_size', '{"name":"TS_hawk_adfiles_getrvqueueinfo_tibrvqueue_size","description":"Event Count in session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780424,"createdAt":1695375780424,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getadapterserviceinformationext_number_of_messages', '{"name":"TS_hawk_dbadapter_getadapterserviceinformationext_number_of_messages","description":"number of rv messages published/received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780737,"createdAt":1695375780737,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getadapterserviceinformationext_line', '{"name":"TS_hawk_dbadapter_getadapterserviceinformationext_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780736,"createdAt":1695375780736,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatusext_uptime', '{"name":"TS_hawk_dbadapter_getstatusext_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781358,"createdAt":1695375781358,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatusext_messages_received', '{"name":"TS_hawk_dbadapter_getstatusext_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781358,"createdAt":1695375781358,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_gethostinformation_hkinfo', '{"name":"TS_hawk_dbadapter_gethostinformation_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"value","computed":false,"expression":"$value","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375780935,"createdAt":1695375780935,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getrvqueueinfo_tibrvqueue_size', '{"name":"TS_hawk_dbadapter_getrvqueueinfo_tibrvqueue_size","description":"Event Count in session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781148,"createdAt":1695375781148,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getrvqueueinfo_tibrvqueue_priority', '{"name":"TS_hawk_dbadapter_getrvqueueinfo_tibrvqueue_priority","description":"Priority of session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781149,"createdAt":1695375781149,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatusext_process_id', '{"name":"TS_hawk_dbadapter_getstatusext_process_id","description":"Process ID set by adapter","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781361,"createdAt":1695375781361,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatusext_messages_sent', '{"name":"TS_hawk_dbadapter_getstatusext_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781359,"createdAt":1695375781359,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatusext_new_errors', '{"name":"TS_hawk_dbadapter_getstatusext_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781360,"createdAt":1695375781360,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatusext_total_errors', '{"name":"TS_hawk_dbadapter_getstatusext_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781361,"createdAt":1695375781361,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getadapterserviceinformation_line', '{"name":"TS_hawk_dbadapter_getadapterserviceinformation_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781750,"createdAt":1695375781750,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getcomponents_hkinfo', '{"name":"TS_hawk_dbadapter_getcomponents_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"component_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"description","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"component_type","type":"STRING"},{"name":"protocol","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"component_name","computed":false,"expression":"$component_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"description","computed":false,"expression":"$description","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"component_type","computed":false,"expression":"$component_type","type":"STRING"},{"name":"protocol","computed":false,"expression":"$protocol","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375781978,"createdAt":1695375781978,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatus_total_errors', '{"name":"TS_hawk_dbadapter_getstatus_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782181,"createdAt":1695375782181,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatus_messages_sent', '{"name":"TS_hawk_dbadapter_getstatus_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782180,"createdAt":1695375782180,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatus_uptime', '{"name":"TS_hawk_dbadapter_getstatus_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782178,"createdAt":1695375782178,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatus_new_errors', '{"name":"TS_hawk_dbadapter_getstatus_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782180,"createdAt":1695375782180,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getstatus_messages_received', '{"name":"TS_hawk_dbadapter_getstatus_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782179,"createdAt":1695375782179,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_dbadapter_getconfig_hkinfo', '{"name":"TS_hawk_dbadapter_getconfig_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"command","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"configuration_url","type":"STRING"},{"name":"repository_connection","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"command","computed":false,"expression":"$command","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"configuration_url","computed":false,"expression":"$configuration_url","type":"STRING"},{"name":"repository_connection","computed":false,"expression":"$repository_connection","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782384,"createdAt":1695375782384,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getadapterserviceinformationext_line', '{"name":"TS_hawk_adldap_getadapterserviceinformationext_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782577,"createdAt":1695375782577,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getadapterserviceinformationext_number_of_messages', '{"name":"TS_hawk_adldap_getadapterserviceinformationext_number_of_messages","description":"number of rv messages published/received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782578,"createdAt":1695375782578,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatusext_uptime', '{"name":"TS_hawk_adldap_getstatusext_uptime","description":"Number of milliseconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782885,"createdAt":1695375782885,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatusext_total_errors', '{"name":"TS_hawk_adldap_getstatusext_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782888,"createdAt":1695375782888,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatusext_process_id', '{"name":"TS_hawk_adldap_getstatusext_process_id","description":"Process ID set by adapter","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782889,"createdAt":1695375782889,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatusext_messages_received', '{"name":"TS_hawk_adldap_getstatusext_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782886,"createdAt":1695375782886,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatusext_messages_sent', '{"name":"TS_hawk_adldap_getstatusext_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782887,"createdAt":1695375782887,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatusext_new_errors', '{"name":"TS_hawk_adldap_getstatusext_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"bw_service_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"bw_service_name","computed":false,"expression":"$bw_service_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375782888,"createdAt":1695375782888,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getadapterserviceinformation_line', '{"name":"TS_hawk_adldap_getadapterserviceinformation_line","description":"row number","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"endpoint_name","type":"STRING"},{"name":"service_name","type":"STRING"},{"name":"subject","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"quality_of_service","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"class","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"endpoint_name","computed":false,"expression":"$endpoint_name","type":"STRING"},{"name":"service_name","computed":false,"expression":"$service_name","type":"STRING"},{"name":"subject","computed":false,"expression":"$subject","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"quality_of_service","computed":false,"expression":"$quality_of_service","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"class","computed":false,"expression":"$class","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375783152,"createdAt":1695375783152,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatus_messages_received', '{"name":"TS_hawk_adldap_getstatus_messages_received","description":"Number of RV messages received","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784198,"createdAt":1695375784198,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_gethostinformation_hkinfo', '{"name":"TS_hawk_adldap_gethostinformation_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"value","computed":false,"expression":"$value","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375783363,"createdAt":1695375783363,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getconfig_hkinfo', '{"name":"TS_hawk_adldap_getconfig_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"command","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"configuration_url","type":"STRING"},{"name":"repository_connection","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"command","computed":false,"expression":"$command","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"configuration_url","computed":false,"expression":"$configuration_url","type":"STRING"},{"name":"repository_connection","computed":false,"expression":"$repository_connection","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375783611,"createdAt":1695375783611,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getrvqueueinfo_tibrvqueue_size', '{"name":"TS_hawk_adldap_getrvqueueinfo_tibrvqueue_size","description":"Event Count in session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375783874,"createdAt":1695375783874,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getrvqueueinfo_tibrvqueue_priority', '{"name":"TS_hawk_adldap_getrvqueueinfo_tibrvqueue_priority","description":"Priority of session''s TibrvQueue","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"session_type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"session_type","computed":false,"expression":"$session_type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375783875,"createdAt":1695375783875,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatus_uptime', '{"name":"TS_hawk_adldap_getstatus_uptime","description":"Number of seconds elapsed since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784198,"createdAt":1695375784198,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatus_new_errors', '{"name":"TS_hawk_adldap_getstatus_new_errors","description":"Number of errors since this method last invoked","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784199,"createdAt":1695375784199,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatus_total_errors', '{"name":"TS_hawk_adldap_getstatus_total_errors","description":"Number of errors since startup","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784200,"createdAt":1695375784200,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getstatus_messages_sent', '{"name":"TS_hawk_adldap_getstatus_messages_sent","description":"Number of RV messages sent","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784199,"createdAt":1695375784199,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_adldap_getcomponents_hkinfo', '{"name":"TS_hawk_adldap_getcomponents_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"session_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"component_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"description","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"component_type","type":"STRING"},{"name":"protocol","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"session_name","computed":false,"expression":"$session_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"component_name","computed":false,"expression":"$component_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"description","computed":false,"expression":"$description","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"component_type","computed":false,"expression":"$component_type","type":"STRING"},{"name":"protocol","computed":false,"expression":"$protocol","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784519,"createdAt":1695375784519,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getstatus_total_errors', '{"name":"TS_hawk_bw5_getstatus_total_errors","description":"Total number of errors since startup.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784912,"createdAt":1695375784912,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getstatus_uptime', '{"name":"TS_hawk_bw5_getstatus_uptime","description":"Number of seconds since startup.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784910,"createdAt":1695375784910,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getstatus_new_errors', '{"name":"TS_hawk_bw5_getstatus_new_errors","description":"Number of errors since the last call to this method.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"process_id","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"adapter_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"instance_id","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"host","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"process_id","computed":false,"expression":"$process_id","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"adapter_name","computed":false,"expression":"$adapter_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"instance_id","computed":false,"expression":"$instance_id","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"host","computed":false,"expression":"$host","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375784911,"createdAt":1695375784911,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_mostrecentelapsedtime', '{"name":"TS_hawk_bw5_getactivities_mostrecentelapsedtime","description":"Most recent ElapsedTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785253,"createdAt":1695375785253,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_mostrecentexecutiontime', '{"name":"TS_hawk_bw5_getactivities_mostrecentexecutiontime","description":"Most recent ExecutionTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785254,"createdAt":1695375785254,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_executioncount', '{"name":"TS_hawk_bw5_getactivities_executioncount","description":"Number of times this activity has been executed by this engine","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785246,"createdAt":1695375785246,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_timesincelastupdate', '{"name":"TS_hawk_bw5_getactivities_timesincelastupdate","description":"Time (milliseconds) since most recent values updated.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785254,"createdAt":1695375785254,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_maxexecutiontime', '{"name":"TS_hawk_bw5_getactivities_maxexecutiontime","description":"Maximum value of ExecutionTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785252,"createdAt":1695375785252,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_executiontime', '{"name":"TS_hawk_bw5_getactivities_executiontime","description":"Total wall-clock time used by all calls of this activity (milliseconds). Does not include waiting time for Sleep, Call process, and Wait activities.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785248,"createdAt":1695375785248,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_maxelapsedtime', '{"name":"TS_hawk_bw5_getactivities_maxelapsedtime","description":"Maximum value of ElapsedTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785250,"createdAt":1695375785250,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_executioncountsincereset', '{"name":"TS_hawk_bw5_getactivities_executioncountsincereset","description":"Number of times this activity has been executed since last reset","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785255,"createdAt":1695375785255,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_errorcount', '{"name":"TS_hawk_bw5_getactivities_errorcount","description":"Number of times this activity has returned an error","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785249,"createdAt":1695375785249,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_minexecutiontime', '{"name":"TS_hawk_bw5_getactivities_minexecutiontime","description":"Minimum value of ExecutionTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785251,"createdAt":1695375785251,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_elapsedtime', '{"name":"TS_hawk_bw5_getactivities_elapsedtime","description":"Total wall-clock time used by all calls of this activity (milliseconds). Includes waiting time for Sleep, Call process, and Wait activities.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785247,"createdAt":1695375785247,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactivities_minelapsedtime', '{"name":"TS_hawk_bw5_getactivities_minelapsedtime","description":"Minimum value of ElaspedTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"tracing","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"calledprocessdefs","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"lastreturncode","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processdefname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"activityclass","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"tracing","computed":false,"expression":"$tracing","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"calledprocessdefs","computed":false,"expression":"$calledprocessdefs","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"lastreturncode","computed":false,"expression":"$lastreturncode","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processdefname","computed":false,"expression":"$processdefname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"activityclass","computed":false,"expression":"$activityclass","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785249,"createdAt":1695375785249,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getexecinfo_uptime', '{"name":"TS_hawk_bw5_getexecinfo_uptime","description":"Elapsed time since engine process was started (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"version","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"version","computed":false,"expression":"$version","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785578,"createdAt":1695375785578,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getexecinfo_threads', '{"name":"TS_hawk_bw5_getexecinfo_threads","description":"Number of worker threads in engine.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"version","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"version","computed":false,"expression":"$version","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785579,"createdAt":1695375785579,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getmemoryusage_totalbytes', '{"name":"TS_hawk_bw5_getmemoryusage_totalbytes","description":"Total number of bytes allocated to the process (free+used)","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785919,"createdAt":1695375785919,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getmemoryusage_freebytes', '{"name":"TS_hawk_bw5_getmemoryusage_freebytes","description":"Total number of available bytes","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785919,"createdAt":1695375785919,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getmemoryusage_percentused', '{"name":"TS_hawk_bw5_getmemoryusage_percentused","description":"Percentage of total bytes that are in use.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785920,"createdAt":1695375785920,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_completed';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_completed', '{"name":"TS_hawk_bw5_getprocessdefinitions_completed","description":"Number of times completed","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786620,"createdAt":1695375786620,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_timesincelastupdate';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_timesincelastupdate', '{"name":"TS_hawk_bw5_getprocessdefinitions_timesincelastupdate","description":"Time (milliseconds) since most recent values updated.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786626,"createdAt":1695375786626,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getmemoryusage_usedbytes', '{"name":"TS_hawk_bw5_getmemoryusage_usedbytes","description":"Total number of bytes in use","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375785920,"createdAt":1695375785920,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocesscount_totalrunningprocesses', '{"name":"TS_hawk_bw5_getprocesscount_totalrunningprocesses","description":"Number of running processes","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786276,"createdAt":1695375786276,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_swapped';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_swapped', '{"name":"TS_hawk_bw5_getprocessdefinitions_swapped","description":"Number of times swapped","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786618,"createdAt":1695375786618,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_totalexecution';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_totalexecution', '{"name":"TS_hawk_bw5_getprocessdefinitions_totalexecution","description":"Total execution time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786621,"createdAt":1695375786621,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_averageexecution';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_averageexecution', '{"name":"TS_hawk_bw5_getprocessdefinitions_averageexecution","description":"Average execution time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786621,"createdAt":1695375786621,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_minexecution';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_minexecution', '{"name":"TS_hawk_bw5_getprocessdefinitions_minexecution","description":"Minimum execution time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786623,"createdAt":1695375786623,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_averageelapsed';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_averageelapsed', '{"name":"TS_hawk_bw5_getprocessdefinitions_averageelapsed","description":"Average elapsed time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786622,"createdAt":1695375786622,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_created';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_created', '{"name":"TS_hawk_bw5_getprocessdefinitions_created","description":"Number of processes created for this process definition","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786617,"createdAt":1695375786617,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_suspended';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_suspended', '{"name":"TS_hawk_bw5_getprocessdefinitions_suspended","description":"Number of times processes using this process definition have been suspended","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786618,"createdAt":1695375786618,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_checkpointed';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_checkpointed', '{"name":"TS_hawk_bw5_getprocessdefinitions_checkpointed","description":"Number of times checkpointed","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786620,"createdAt":1695375786620,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_mostrecentelapsedtime';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_mostrecentelapsedtime', '{"name":"TS_hawk_bw5_getprocessdefinitions_mostrecentelapsedtime","description":"Most recent ElapsedTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786626,"createdAt":1695375786626,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_countsincereset';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_countsincereset', '{"name":"TS_hawk_bw5_getprocessdefinitions_countsincereset","description":"Processes completed since last reset","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786627,"createdAt":1695375786627,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_maxelapsed';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_maxelapsed', '{"name":"TS_hawk_bw5_getprocessdefinitions_maxelapsed","description":"Maximum elapsed time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786623,"createdAt":1695375786623,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_aborted';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_aborted', '{"name":"TS_hawk_bw5_getprocessdefinitions_aborted","description":"Number of times aborted","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786619,"createdAt":1695375786619,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_mostrecentexecutiontime';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_mostrecentexecutiontime', '{"name":"TS_hawk_bw5_getprocessdefinitions_mostrecentexecutiontime","description":"Most recent ExecutionTime (milliseconds).","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786625,"createdAt":1695375786625,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_minelapsed';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_minelapsed', '{"name":"TS_hawk_bw5_getprocessdefinitions_minelapsed","description":"Minimum elapsed time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786623,"createdAt":1695375786623,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_totalelapsed';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_totalelapsed', '{"name":"TS_hawk_bw5_getprocessdefinitions_totalelapsed","description":"Total elapsed time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786622,"createdAt":1695375786622,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_queued';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_queued', '{"name":"TS_hawk_bw5_getprocessdefinitions_queued","description":"Number of times queued","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786619,"createdAt":1695375786619,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_bw5_getprocessdefinitions_maxexecution';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessdefinitions_maxexecution', '{"name":"TS_hawk_bw5_getprocessdefinitions_maxexecution","description":"Maximum execution time of all processes completed using this process definition (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"starter","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name":"service_instance","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"starter","computed":false,"expression":"$starter","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name":"service_instance","computed":false,"expression":"$service_instance","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786625,"createdAt":1695375786625,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessstarters_completed', '{"name":"TS_hawk_bw5_getprocessstarters_completed","description":"Number of processes completed","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"start_time","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"processdef","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"start_time","computed":false,"expression":"$start_time","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"processdef","computed":false,"expression":"$processdef","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786921,"createdAt":1695375786921,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessstarters_running', '{"name":"TS_hawk_bw5_getprocessstarters_running","description":"Number of processes currently running","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"start_time","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"processdef","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"start_time","computed":false,"expression":"$start_time","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"processdef","computed":false,"expression":"$processdef","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786920,"createdAt":1695375786920,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessstarters_created', '{"name":"TS_hawk_bw5_getprocessstarters_created","description":"Number of processes created","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"start_time","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"processdef","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"start_time","computed":false,"expression":"$start_time","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"processdef","computed":false,"expression":"$processdef","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786919,"createdAt":1695375786919,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessstarters_duration', '{"name":"TS_hawk_bw5_getprocessstarters_duration","description":"Elapsed wall-clock time since the process starter started (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"start_time","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"processdef","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"start_time","computed":false,"expression":"$start_time","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"processdef","computed":false,"expression":"$processdef","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786921,"createdAt":1695375786921,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocessstarters_creationrate', '{"name":"TS_hawk_bw5_getprocessstarters_creationrate","description":"Rate of process creation (processes/hour)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"app_type","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"start_time","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"processdef","type":"STRING"},{"name":"status","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"app_type","computed":false,"expression":"$app_type","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"start_time","computed":false,"expression":"$start_time","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"processdef","computed":false,"expression":"$processdef","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375786920,"createdAt":1695375786920,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getrecoverableprocesses_id', '{"name":"TS_hawk_bw5_getrecoverableprocesses_id","description":"Id","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"restartactivity","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"processname","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"customid","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"id","type":"STRING"},{"name":"status","type":"STRING"},{"name":"trackingid","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"restartactivity","computed":false,"expression":"$restartactivity","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"processname","computed":false,"expression":"$processname","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"customid","computed":false,"expression":"$customid","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"trackingid","computed":false,"expression":"$trackingid","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375787294,"createdAt":1695375787294,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getactiveprocesscount_totalactiveprocesses', '{"name":"TS_hawk_bw5_getactiveprocesscount_totalactiveprocesses","description":"Number of active, not paged, processes","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375787570,"createdAt":1695375787570,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_listlocks_waitposition', '{"name":"TS_hawk_bw5_listlocks_waitposition","description":"Wait position","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"requestor","type":"STRING"},{"name":"lockname","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"id","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"requestor","computed":false,"expression":"$requestor","type":"STRING"},{"name":"lockname","computed":false,"expression":"$lockname","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698905409572,"createdAt":1698905409572,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_gethostinformation_hkinfo', '{"name":"TS_hawk_bw5_gethostinformation_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"value","computed":false,"expression":"$value","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788105,"createdAt":1695375788105,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocesses_duration', '{"name":"TS_hawk_bw5_getprocesses_duration","description":"Elapsed wall-clock time since the process started (milliseonds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"mainprocessname","type":"STRING"},{"name":"startername","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"customid","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"currentactivityname","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"subprocessname","type":"STRING"},{"name":"id","type":"STRING"},{"name":"status","type":"STRING"},{"name":"trackingid","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"mainprocessname","computed":false,"expression":"$mainprocessname","type":"STRING"},{"name":"startername","computed":false,"expression":"$startername","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"customid","computed":false,"expression":"$customid","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"currentactivityname","computed":false,"expression":"$currentactivityname","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"subprocessname","computed":false,"expression":"$subprocessname","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"trackingid","computed":false,"expression":"$trackingid","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788433,"createdAt":1695375788433,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_bw5_getprocesses_starttime', '{"name":"TS_hawk_bw5_getprocesses_starttime","description":"Time at which the process started (milliseconds)","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"mainprocessname","type":"STRING"},{"name":"startername","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"customid","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"currentactivityname","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"name","type":"STRING"},{"name":"subprocessname","type":"STRING"},{"name":"id","type":"STRING"},{"name":"status","type":"STRING"},{"name":"trackingid","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"mainprocessname","computed":false,"expression":"$mainprocessname","type":"STRING"},{"name":"startername","computed":false,"expression":"$startername","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"customid","computed":false,"expression":"$customid","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"currentactivityname","computed":false,"expression":"$currentactivityname","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"subprocessname","computed":false,"expression":"$subprocessname","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"status","computed":false,"expression":"$status","type":"STRING"},{"name":"trackingid","computed":false,"expression":"$trackingid","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788433,"createdAt":1695375788433,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_sysinfo_gethostname_hkinfo', '{"name":"TS_hawk_sysinfo_gethostname_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"host_name","type":"STRING"},{"name":"agent_domain","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"host_name","computed":false,"expression":"$host_name","type":"STRING"},{"name":"agent_domain","computed":false,"expression":"$agent_domain","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788584,"createdAt":1695375788584,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_sysinfo_getoperatingsystem_hkinfo', '{"name":"TS_hawk_sysinfo_getoperatingsystem_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"os_name","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"os_version","computed":false,"expression":"$os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"os_name","computed":false,"expression":"$os_name","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788621,"createdAt":1695375788621,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_self_getmicroagentinfo_count', '{"name":"TS_hawk_self_getmicroagentinfo_count","description":"The number of microagents","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"display_name","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"name","computed":false,"expression":"$name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"display_name","computed":false,"expression":"$display_name","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788716,"createdAt":1695375788716,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_getprocesses_mem_usage', '{"name":"TS_hawk_tra_getprocesses_mem_usage","description":"memory usage","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"pid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"pid","computed":false,"expression":"$pid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788780,"createdAt":1695375788780,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_getprocesses_cpu_time', '{"name":"TS_hawk_tra_getprocesses_cpu_time","description":"cpu usage","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"pid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"pid","computed":false,"expression":"$pid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788779,"createdAt":1695375788779,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_getprocesses_cpu_percent', '{"name":"TS_hawk_tra_getprocesses_cpu_percent","description":"cpu usage percentage","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"pid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"pid","computed":false,"expression":"$pid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788779,"createdAt":1695375788779,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_getinstalledtibcoproducts_hkinfo', '{"name":"TS_hawk_tra_getinstalledtibcoproducts_hkinfo","description":"This is a placeholder metric to expose non numeral information.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"component_path","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"version","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"installed_tibco_products","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"component_path","computed":false,"expression":"$component_path","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"version","computed":false,"expression":"$version","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"installed_tibco_products","computed":false,"expression":"$installed_tibco_products","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1695375788861,"createdAt":1695375788861,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_tra_onnewstatusorcmd_cpu_percent';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_onnewstatusorcmd_cpu_percent', '{"name":"TS_hawk_tra_onnewstatusorcmd_cpu_percent","description":"cpu used percentage.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"data","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"out_of_sync","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"component_instance","type":"STRING"},{"name":"id","type":"STRING"},{"name":"state","type":"STRING"},{"name":"service_instance_name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name": "microagent_instance","type": "STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"data","computed":false,"expression":"$data","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"out_of_sync","computed":false,"expression":"$out_of_sync","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"component_instance","computed":false,"expression":"$component_instance","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"state","computed":false,"expression":"$state","type":"STRING"},{"name":"service_instance_name","computed":false,"expression":"$service_instance_name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name": "microagent_instance","computed": false,"expression": "$microagent_instance","type": "STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698922325612,"createdAt":1698922325612,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_tra_onnewstatusorcmd_usage_percent';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_onnewstatusorcmd_usage_percent', '{"name":"TS_hawk_tra_onnewstatusorcmd_usage_percent","description":"usage percent. MACHINE_START time also uses this column.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"data","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"out_of_sync","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"component_instance","type":"STRING"},{"name":"id","type":"STRING"},{"name":"state","type":"STRING"},{"name":"service_instance_name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name": "microagent_instance","type": "STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"data","computed":false,"expression":"$data","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"out_of_sync","computed":false,"expression":"$out_of_sync","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"component_instance","computed":false,"expression":"$component_instance","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"state","computed":false,"expression":"$state","type":"STRING"},{"name":"service_instance_name","computed":false,"expression":"$service_instance_name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name": "microagent_instance","computed": false,"expression": "$microagent_instance","type": "STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698922325610,"createdAt":1698922325610,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_tra_onnewstatusorcmd_credential';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_onnewstatusorcmd_credential', '{"name":"TS_hawk_tra_onnewstatusorcmd_credential","description":"public key for security purpose.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"data","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"out_of_sync","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"component_instance","type":"STRING"},{"name":"id","type":"STRING"},{"name":"state","type":"STRING"},{"name":"service_instance_name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name": "microagent_instance","type": "STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"data","computed":false,"expression":"$data","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"out_of_sync","computed":false,"expression":"$out_of_sync","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"component_instance","computed":false,"expression":"$component_instance","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"state","computed":false,"expression":"$state","type":"STRING"},{"name":"service_instance_name","computed":false,"expression":"$service_instance_name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name": "microagent_instance","computed": false,"expression": "$microagent_instance","type": "STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698922325613,"createdAt":1698922325613,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_tra_onnewstatusorcmd_cpu_total';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_onnewstatusorcmd_cpu_total', '{"name":"TS_hawk_tra_onnewstatusorcmd_cpu_total","description":"total cpu time.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"data","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"out_of_sync","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"component_instance","type":"STRING"},{"name":"id","type":"STRING"},{"name":"state","type":"STRING"},{"name":"service_instance_name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name": "microagent_instance","type": "STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"data","computed":false,"expression":"$data","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"out_of_sync","computed":false,"expression":"$out_of_sync","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"component_instance","computed":false,"expression":"$component_instance","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"state","computed":false,"expression":"$state","type":"STRING"},{"name":"service_instance_name","computed":false,"expression":"$service_instance_name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name": "microagent_instance","computed": false,"expression": "$microagent_instance","type": "STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698922325612,"createdAt":1698922325612,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_tra_onnewstatusorcmd_mem_usage';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_onnewstatusorcmd_mem_usage', '{"name":"TS_hawk_tra_onnewstatusorcmd_mem_usage","description":"memory usage.","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"data","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"out_of_sync","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"component_instance","type":"STRING"},{"name":"id","type":"STRING"},{"name":"state","type":"STRING"},{"name":"service_instance_name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name": "microagent_instance","type": "STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"data","computed":false,"expression":"$data","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"out_of_sync","computed":false,"expression":"$out_of_sync","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"component_instance","computed":false,"expression":"$component_instance","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"state","computed":false,"expression":"$state","type":"STRING"},{"name":"service_instance_name","computed":false,"expression":"$service_instance_name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name": "microagent_instance","computed": false,"expression": "$microagent_instance","type": "STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698922325613,"createdAt":1698922325613,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_tra_onnewstatusorcmd_used';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_onnewstatusorcmd_used', '{"name":"TS_hawk_tra_onnewstatusorcmd_used","description":"disk usage","active":true,"sourceFilter":"","columns":[{"name":"microagent_display_name","type":"STRING"},{"name":"data","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"out_of_sync","type":"STRING"},{"name":"type","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"agent_ip","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"process_name","type":"STRING"},{"name":"component_instance","type":"STRING"},{"name":"id","type":"STRING"},{"name":"state","type":"STRING"},{"name":"service_instance_name","type":"STRING"},{"name":"deployment","type":"STRING"},{"name": "microagent_instance","type": "STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"data","computed":false,"expression":"$data","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"out_of_sync","computed":false,"expression":"$out_of_sync","type":"STRING"},{"name":"type","computed":false,"expression":"$type","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"process_name","computed":false,"expression":"$process_name","type":"STRING"},{"name":"component_instance","computed":false,"expression":"$component_instance","type":"STRING"},{"name":"id","computed":false,"expression":"$id","type":"STRING"},{"name":"state","computed":false,"expression":"$state","type":"STRING"},{"name":"service_instance_name","computed":false,"expression":"$service_instance_name","type":"STRING"},{"name":"deployment","computed":false,"expression":"$deployment","type":"STRING"},{"name": "microagent_instance","computed": false,"expression": "$microagent_instance","type": "STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698922325612,"createdAt":1698922325612,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
    ('TS_hawk_microagents', '{"name":"TS_hawk_microagents",
  "description":" microagents for a tag",
  "active":true,
  "sourceFilter":"",
  "columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"tagname","type":"STRING"},{"name":"value","type":"FLOAT"}],
  "parsingRules":
  [{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"display_name","computed":false,"expression":"$display_name","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"tagname","computed":false,"expression":"$tagname","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],
  "lastUpdated":1695375788716,
  "createdAt":1695375788716,
  "createdBy":"admin",
  "parentPath":"/User",
  "groupDetails":""
}') ON CONFLICT DO NOTHING;

DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_microagents_total';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
    ('TS_hawk_microagents_total', '{"name":"TS_hawk_microagents_total",
  "description":" microagents for a tag",
  "active":true,
  "sourceFilter":"",
  "columns":[{"name":"subid","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"tag_name","type":"STRING"},{"name":"value","type":"FLOAT"}],
  "parsingRules":
  [{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"tag_name","computed":false,"expression":"$tag_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],
  "lastUpdated":1695375788716,
  "createdAt":1695375788716,
  "createdBy":"admin",
  "parentPath":"/User",
  "groupDetails":""
}') ON CONFLICT DO NOTHING;

INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
    ('TS_hawk_bw5_appstatus', '{"name":"TS_hawk_bw5_appstatus",
  "description":" hawk_bw5_appstatus Application status Stopped/Running",
  "active":true,
  "sourceFilter":"",
  "columns":[{"name":"subid","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"value","type":"FLOAT"}],
  "parsingRules":
  [{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"tagname","computed":false,"expression":"app_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],
  "lastUpdated":1695375788716,
  "createdAt":1695375788716,
  "createdBy":"admin",
  "parentPath":"/User",
  "groupDetails":""
}') ON CONFLICT DO NOTHING;


INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
    ('TS_hawk_bw5_componentstatus', '{"name":"TS_hawk_bw5_componentstatus",
  "description":" Component status Stopped/Running",
  "active":true,
  "sourceFilter":"",
  "columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"microagent_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"domain_name","type":"STRING"},{"name":"agent_name","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"app_name","type":"STRING"},{"name":"app_instance_name","type":"STRING"},{"name":"value","type":"FLOAT"}],
  "parsingRules":
  [{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"domain_name","computed":false,"expression":"$domain_name","type":"STRING"},{"name":"agent_name","computed":false,"expression":"$agent_name","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"display_name","computed":false,"expression":"$display_name","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"app_name","computed":false,"expression":"$app_name","type":"STRING"},{"name":"app_instance_name","computed":false,"expression":"$app_instance_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],
  "lastUpdated":1695375788716,
  "createdAt":1695375788716,
  "createdBy":"admin",
  "parentPath":"/User",
  "groupDetails":""
}') ON CONFLICT DO NOTHING;

INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getcpuinfo_percent_user_time', '{"name":"TS_hawk_syswin_getcpuinfo_percent_user_time","description":"Percent of the time spent in \"user\" mode for this processor.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824675990,"createdAt":1698824675990,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getcpuinfo_total_cpus', '{"name":"TS_hawk_syswin_getcpuinfo_total_cpus","description":"Total number of CPUs","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824675989,"createdAt":1698824675989,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getcpuinfo_percent_system_time', '{"name":"TS_hawk_syswin_getcpuinfo_percent_system_time","description":"Percent of the time spent in \"system\" mode for this processor.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824675990,"createdAt":1698824675990,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getcpuinfo_percent_time_usage', '{"name":"TS_hawk_syswin_getcpuinfo_percent_time_usage","description":"% Time Usage","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824675991,"createdAt":1698824675991,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getcpuinfo_percent_time_idle', '{"name":"TS_hawk_syswin_getcpuinfo_percent_time_idle","description":"Percent of the time spent in \"idle\" mode for this processor.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824675990,"createdAt":1698824675990,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getsysteminfo_up_time', '{"name":"TS_hawk_syswin_getsysteminfo_up_time","description":"System up time in seconds","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824689629,"createdAt":1698824689629,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getsysteminfo_free_real_memory', '{"name":"TS_hawk_syswin_getsysteminfo_free_real_memory","description":"KBytes Free Real Memory","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824689630,"createdAt":1698824689630,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getsysteminfo_percent_free_real_memory', '{"name":"TS_hawk_syswin_getsysteminfo_percent_free_real_memory","description":"% Free Real Memory","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824689630,"createdAt":1698824689630,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getsysteminfo_percent_used_real_memory', '{"name":"TS_hawk_syswin_getsysteminfo_percent_used_real_memory","description":"% Used Real Memory","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824689630,"createdAt":1698824689630,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getsysteminfo_total_real_memory', '{"name":"TS_hawk_syswin_getsysteminfo_total_real_memory","description":"KBytes Total Real Memory","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824689629,"createdAt":1698824689629,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswin_getsysteminfo_used_real_memory', '{"name":"TS_hawk_syswin_getsysteminfo_used_real_memory","description":"KBytes Used Real Memory","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698824689630,"createdAt":1698824689630,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getcpuinfo_percent_time_idle', '{"name":"TS_hawk_syslinux_getcpuinfo_percent_time_idle","description":"Percent of the time spent in \"idle\" mode for this processor.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processor","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processor","computed":false,"expression":"$processor","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125963,"createdAt":1698820125963,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getcpuinfo_percent_system_time', '{"name":"TS_hawk_syslinux_getcpuinfo_percent_system_time","description":"Percent of the time spent in \"system\" mode for this processor.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processor","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processor","computed":false,"expression":"$processor","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125962,"createdAt":1698820125962,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getcpuinfo_percent_user_time', '{"name":"TS_hawk_syslinux_getcpuinfo_percent_user_time","description":"Percent of the time spent in \"user\" mode for this processor.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"processor","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"processor","computed":false,"expression":"$processor","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125962,"createdAt":1698820125962,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syswinperf_logicaldisk_percent_free_space', '{"name":"TS_hawk_syswinperf_logicaldisk_percent_free_space","description":"No help available.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"logicaldisk","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"logicaldisk","computed":false,"expression":"$logicaldisk","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820136293,"createdAt":1698820136293,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinuxfile_getbypartition_percent_free', '{"name":"TS_hawk_syslinuxfile_getbypartition_percent_free","description":"Amount of disk space on the mounted file system that is currently free, expressed as percentage of total size.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"partition","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"mount_point","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"partition","computed":false,"expression":"$partition","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"mount_point","computed":false,"expression":"$mount_point","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820123864,"createdAt":1698820123864,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinuxfile_getbypartition_percent_used', '{"name":"TS_hawk_syslinuxfile_getbypartition_percent_used","description":"Amount of disk space on the mounted file system currently in use, expressed as percentage of total size.","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"partition","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"mount_point","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"partition","computed":false,"expression":"$partition","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"mount_point","computed":false,"expression":"$mount_point","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820123865,"createdAt":1698820123865,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getsysteminfo_percent_time_usage', '{"name":"TS_hawk_syslinux_getsysteminfo_percent_time_usage","description":"% Time Usage","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125841,"createdAt":1698820125841,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getsysteminfo_free_memory', '{"name":"TS_hawk_syslinux_getsysteminfo_free_memory","description":"Total free memory in KBytes","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125840,"createdAt":1698820125840,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getsysteminfo_real_memory', '{"name":"TS_hawk_syslinux_getsysteminfo_real_memory","description":"Total physical memory in KBytes","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125840,"createdAt":1698820125840,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_syslinux_getsysteminfo_percent_free_real_memory', '{"name":"TS_hawk_syslinux_getsysteminfo_percent_free_real_memory","description":"% Free Real Memory","active":true,"sourceFilter":"","columns":[{"name":"agent_ip","type":"STRING"},{"name":"microagent_display_name","type":"STRING"},{"name":"subid","type":"STRING"},{"name":"agent_os_name","type":"STRING"},{"name":"agent_os_version","type":"STRING"},{"name":"dpid","type":"STRING"},{"name":"agent_host_name","type":"STRING"},{"name":"value","type":"FLOAT"}],"parsingRules":[{"name":"Rule_1","enabled":true,"filter":"","parserProperties":{"separator":"|","delimiter":":","encoding":"UTF-8","parser_type":"keyvalue","beginningRegex":""},"columns":[{"name":"agent_ip","computed":false,"expression":"$agent_ip","type":"STRING"},{"name":"microagent_display_name","computed":false,"expression":"$microagent_display_name","type":"STRING"},{"name":"subid","computed":false,"expression":"$subid","type":"STRING"},{"name":"agent_os_name","computed":false,"expression":"$agent_os_name","type":"STRING"},{"name":"agent_os_version","computed":false,"expression":"$agent_os_version","type":"STRING"},{"name":"dpid","computed":false,"expression":"$dpid","type":"STRING"},{"name":"agent_host_name","computed":false,"expression":"$agent_host_name","type":"STRING"},{"name":"Value","computed":false,"expression":"$value","type":"FLOAT"}]}],"lastUpdated":1698820125841,"createdAt":1698820125841,"createdBy":"admin","parentPath":"/User","groupDetails":""}') ON CONFLICT DO NOTHING;
--CT 1.1.0 changes
-- Datamodel TS_hawk_tra_getserviceinstancesdetails_statecode was added in CT 1.1.0. 
-- TS_hawk_tra_getserviceinstancesdetails_statecode - label `state` was removed in CT 1.1.0. label `archive_instance` was added in CT 1.1.0
-- TS_hawk_tra_getserviceinstancesdetails_statecode - label `deployment_name` was added in CT 1.2.0.
DELETE FROM redtail_ct_info.datamodel where name= 'TS_hawk_tra_getserviceinstancesdetails_statecode';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_tra_getserviceinstancesdetails_statecode', '{
  "name": "TS_hawk_tra_getserviceinstancesdetails_statecode",
  "description": "StateCode",
  "active": true,
  "sourceFilter": "",
  "columns": [
    {
      "name": "microagent_display_name",
      "type": "STRING"
    },
    {
      "name": "archive_instance",
      "type": "STRING"
    },
    {
      "name": "software",
      "type": "STRING"
    },
    {
      "name": "agent_name",
      "type": "STRING"
    },
    {
      "name": "agent_os_version",
      "type": "STRING"
    },
    {
      "name": "ft_group",
      "type": "STRING"
    },
    {
      "name": "deployment_name",
      "type": "STRING"
    },
    {
      "name": "dpid",
      "type": "STRING"
    },
    {
      "name": "agent_host_name",
      "type": "STRING"
    },
    {
      "name": "agent_ip",
      "type": "STRING"
    },
    {
      "name": "subid",
      "type": "STRING"
    },
    {
      "name": "domain_name",
      "type": "STRING"
    },
    {
      "name": "application_name",
      "type": "STRING"
    },
    {
      "name": "agent_os_name",
      "type": "STRING"
    },
    {
      "name": "microagent_instance",
      "type": "STRING"
    },
    {
      "name": "service_instance",
      "type": "STRING"
    },
    {
      "name": "value",
      "type": "FLOAT"
    }
  ],
  "parsingRules": [
    {
      "name": "Rule_1",
      "enabled": true,
      "filter": "",
      "parserProperties": {
        "separator": "|",
        "delimiter": ":",
        "encoding": "UTF-8",
        "parser_type": "keyvalue",
        "beginningRegex": ""
      },
      "columns": [
        {
          "name": "microagent_display_name",
          "computed": false,
          "expression": "$microagent_display_name",
          "type": "STRING"
        },
        {
          "name": "archive_instance",
          "computed": false,
          "expression": "$archive_instance",
          "type": "STRING"
        },
        {
          "name": "software",
          "computed": false,
          "expression": "$software",
          "type": "STRING"
        },
        {
          "name": "agent_name",
          "computed": false,
          "expression": "$agent_name",
          "type": "STRING"
        },
        {
          "name": "agent_os_version",
          "computed": false,
          "expression": "$agent_os_version",
          "type": "STRING"
        },
        {
          "name": "ft_group",
          "computed": false,
          "expression": "$ft_group",
          "type": "STRING"
        },
        {
          "name": "deployment_name",
          "computed": false,
          "expression": "$deployment_name",
          "type": "STRING"
        },
        {
          "name": "dpid",
          "computed": false,
          "expression": "$dpid",
          "type": "STRING"
        },
        {
          "name": "agent_host_name",
          "computed": false,
          "expression": "$agent_host_name",
          "type": "STRING"
        },
        {
          "name": "agent_ip",
          "computed": false,
          "expression": "$agent_ip",
          "type": "STRING"
        },
        {
          "name": "subid",
          "computed": false,
          "expression": "$subid",
          "type": "STRING"
        },
        {
          "name": "domain_name",
          "computed": false,
          "expression": "$domain_name",
          "type": "STRING"
        },
        {
          "name": "application_name",
          "computed": false,
          "expression": "$application_name",
          "type": "STRING"
        },
        {
          "name": "agent_os_name",
          "computed": false,
          "expression": "$agent_os_name",
          "type": "STRING"
        },
        {
          "name": "microagent_instance",
          "computed": false,
          "expression": "$microagent_instance",
          "type": "STRING"
        },
        {
          "name": "service_instance",
          "computed": false,
          "expression": "$service_instance",
          "type": "STRING"
        },
        {
          "name": "Value",
          "computed": false,
          "expression": "$value",
          "type": "FLOAT"
        }
      ]
    }
  ],
  "lastUpdated": 1712312567721,
  "createdAt": 1712312567721,
  "createdBy": "admin",
  "parentPath": "/User",
  "groupDetails": ""
}') ON CONFLICT DO NOTHING;
--CT 1.2.0 changes
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config)
VALUES ('TS_hawk_domain_state', '
{
            "name": "TS_hawk_domain_state",
            "description": "State of domains .Values description:1-DOMAIN REGISTERED 0-DOMAIN UNREGISTERED -1-DOMAIN DISCONNECTED",
            "active": true,
            "sourceFilter": "",
            "parsingRules": [
                {
                    "name": "Rule_1",
                    "filter": "",
                    "parserProperties": {
                        "separator": "|",
                        "delimiter": ":",
                        "encoding": "UTF-8",
                        "parser_type": "keyvalue",
                        "beginningRegex": ""
                    },
                    "columns": [
                        {
                            "name": "subid",
                            "computed": false,
                            "expression": "$subid",
                            "type": "STRING"
                        },
                        {
                            "name": "domain_name",
                            "computed": false,
                            "expression": "$domain_name",
                            "type": "STRING"
                        },
                        {
                            "name": "dpid",
                            "computed": false,
                            "expression": "$dpid",
                            "type": "STRING"
                        },
                        {
                            "name": "transport_type",
                            "computed": false,
                            "expression": "$transport_type",
                            "type": "STRING"
                        },
                        {
                            "name": "ems_url",
                            "computed": false,
                            "expression": "$ems_url",
                            "type": "STRING"
                        } ,
                        {
                            "name": "rv_service",
                            "computed": false,
                            "expression": "$rv_service",
                            "type": "STRING"
                        },
                        {
                            "name": "rv_network",
                            "computed": false,
                            "expression": "$rv_network",
                            "type": "STRING"
                        },
                        {
                            "name": "rv_daemon_port",
                            "computed": false,
                            "expression": "$rv_daemon_port",
                            "type": "STRING"
                        },
                        {
                             "name":"Value",
                             "computed":false,
                             "expression":"$value",
                             "type":"FLOAT"
                        }
                    ],
                    "enabled": true
                }
            ],
            "columns": [
                  {
                            "name": "subid",
                            "computed": false,
                            "expression": "$subid",
                            "type": "STRING"
                        },
                        {
                            "name": "domain_name",
                            "computed": false,
                            "expression": "$domain_name",
                            "type": "STRING"
                        },
                        {
                            "name": "dpid",
                            "computed": false,
                            "expression": "$dpid",
                            "type": "STRING"
                        },
                        {
                            "name": "transport_type",
                            "computed": false,
                            "expression": "$transport_type",
                            "type": "STRING"
                        },
                        {
                            "name": "ems_url",
                            "computed": false,
                            "expression": "$ems_url",
                            "type": "STRING"
                        } ,
                        {
                            "name": "rv_service",
                            "computed": false,
                            "expression": "$rv_service",
                            "type": "STRING"
                        },
                        {
                            "name": "rv_network",
                            "computed": false,
                            "expression": "$rv_network",
                            "type": "STRING"
                        } ,
                        {
                            "name": "rv_daemon_port",
                            "computed": false,
                            "expression": "$rv_daemon_port",
                            "type": "STRING"
                        },
                        {
                                 "name":"value",
                                 "computed":false,
                                 "expression":"$value",
                                 "type":"FLOAT"
                        }
            ],
            "createdAt": 1710316625611,
            "createdBy": "admin",
            "lastUpdated": "1710316625611",
            "parentPath": "/User",
            "groupDetails": ""
}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel where name= 'TS_hawk_tra_getapplicationdeploymentdetails_id'; 
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config)
VALUES ('TS_hawk_tra_getapplicationdeploymentdetails_id',
 '{
  "name": "TS_hawk_tra_getapplicationdeploymentdetails_id",
  "description": "ID",
  "active": true,
  "sourceFilter": "",
  "columns": [
    {
      "name": "microagent_display_name",
      "type": "STRING"
    },
    {
      "name": "agent_name",
      "type": "STRING"
    },
    {
      "name": "agent_os_version",
      "type": "STRING"
    },
    {
      "name": "deployment_name",
      "type": "STRING"
    },
    {
      "name": "package_owner",
      "type": "STRING"
    },
    {
      "name": "dpid",
      "type": "STRING"
    },
    {
      "name": "deployment_status",
      "type": "STRING"
    },
    {
      "name": "agent_host_name",
      "type": "STRING"
    },
    {
      "name": "package_description",
      "type": "STRING"
    },
    {
      "name": "agent_ip",
      "type": "STRING"
    },
    {
      "name": "subid",
      "type": "STRING"
    },
    {
      "name": "path",
      "type": "STRING"
    },
    {
      "name": "domain_name",
      "type": "STRING"
    },
    {
      "name": "application_name",
      "type": "STRING"
    },
    {
      "name": "package_version",
      "type": "STRING"
    },
    {
      "name": "agent_os_name",
      "type": "STRING"
    },
    {
      "name": "package_name",
      "type": "STRING"
    },
    {
      "name": "deployability",
      "type": "STRING"
    },
    {
      "name": "package_creation_date",
      "type": "STRING"
    },
    {
      "name": "history_number",
      "type": "STRING"
    },
    {
      "name": "microagent_instance",
      "type": "STRING"
    },
    {
      "name": "value",
      "type": "FLOAT"
    }
  ],
  "parsingRules": [
    {
      "name": "Rule_1",
      "enabled": true,
      "filter": "",
      "parserProperties": {
        "separator": "|",
        "delimiter": ":",
        "encoding": "UTF-8",
        "parser_type": "keyvalue",
        "beginningRegex": ""
      },
      "columns": [
        {
          "name": "microagent_display_name",
          "computed": false,
          "expression": "$microagent_display_name",
          "type": "STRING"
        },
        {
          "name": "agent_name",
          "computed": false,
          "expression": "$agent_name",
          "type": "STRING"
        },
        {
          "name": "agent_os_version",
          "computed": false,
          "expression": "$agent_os_version",
          "type": "STRING"
        },
        {
          "name": "deployment_name",
          "computed": false,
          "expression": "$deployment_name",
          "type": "STRING"
        },
        {
          "name": "package_owner",
          "computed": false,
          "expression": "$package_owner",
          "type": "STRING"
        },
        {
          "name": "dpid",
          "computed": false,
          "expression": "$dpid",
          "type": "STRING"
        },
        {
          "name": "deployment_status",
          "computed": false,
          "expression": "$deployment_status",
          "type": "STRING"
        },
        {
          "name": "agent_host_name",
          "computed": false,
          "expression": "$agent_host_name",
          "type": "STRING"
        },
        {
          "name": "package_description",
          "computed": false,
          "expression": "$package_description",
          "type": "STRING"
        },
        {
          "name": "agent_ip",
          "computed": false,
          "expression": "$agent_ip",
          "type": "STRING"
        },
        {
          "name": "subid",
          "computed": false,
          "expression": "$subid",
          "type": "STRING"
        },
        {
          "name": "path",
          "computed": false,
          "expression": "$path",
          "type": "STRING"
        },
        {
          "name": "domain_name",
          "computed": false,
          "expression": "$domain_name",
          "type": "STRING"
        },
        {
          "name": "application_name",
          "computed": false,
          "expression": "$application_name",
          "type": "STRING"
        },
        {
          "name": "package_version",
          "computed": false,
          "expression": "$package_version",
          "type": "STRING"
        },
        {
          "name": "agent_os_name",
          "computed": false,
          "expression": "$agent_os_name",
          "type": "STRING"
        },
        {
          "name": "package_name",
          "computed": false,
          "expression": "$package_name",
          "type": "STRING"
        },
        {
          "name": "deployability",
          "computed": false,
          "expression": "$deployability",
          "type": "STRING"
        },
        {
          "name": "package_creation_date",
          "computed": false,
          "expression": "$package_creation_date",
          "type": "STRING"
        },
        {
          "name": "history_number",
          "computed": false,
          "expression": "$history_number",
          "type": "STRING"
        },
        {
          "name": "microagent_instance",
          "computed": false,
          "expression": "$microagent_instance",
          "type": "STRING"
        },
        {
          "name": "Value",
          "computed": false,
          "expression": "$value",
          "type": "FLOAT"
        }
      ]
    }
  ],
  "lastUpdated": 1712312509261,
  "createdAt": 1712312509261,
  "createdBy": "admin",
  "parentPath": "/User",
  "groupDetails": ""
}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_microagent_state';
INSERT INTO redtail_ct_info.datamodel(name, datamodel_config) VALUES('TS_hawk_microagent_state','{
  "version": "1",
  "name": "TS_hawk_microagent_state",
  "active": "true",
  "createdBy": "System",
  "createdAt": "",
  "lastUpdated": "",
  "sourceFilter": "",
  "parsingRules": [],
  "parentPath":"/User",
  "groupDetails":"",
  "columns": [
    {"name": "domain_name", "type": "STRING"},
    {"name": "agent_host_name", "type": "STRING"},
    {"name": "agent_ip", "type": "STRING"},
    {"name": "agent_name", "type": "STRING"},
    {"name": "agent_os_name", "type": "STRING"},
    {"name": "agent_os_version", "type": "STRING"},
    {"name": "instance", "type": "STRING"},
    {"name": "name", "type": "STRING"},
    {"name": "display_name", "type": "STRING"},
    {"name": "microagent_instance", "type": "STRING"},
    {"name": "tag_name", "type": "STRING"},
    {"name": "subid", "type": "STRING"},
    {"name": "dpid", "type": "STRING"},
    {"name": "job", "type": "STRING"},
    {"name": "hkbe_app_name", "type": "STRING"},
    {"name": "hkbe_cluster_name", "type": "STRING"},
    {
          "name":"value",
          "computed":false,
          "expression":"$value",
          "type":"FLOAT"
    }
  ],
  "groupName": "System"
}') ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS SCHEMA_VERSION (
	ID SERIAL PRIMARY KEY,
	VERSION INTEGER NOT NULL,

	CONSTRAINT SCHEMA_VERSION_UNIQUE_CONSTRAINT UNIQUE (VERSION)
);

INSERT INTO SCHEMA_VERSION (VERSION) VALUES (1) ON CONFLICT DO NOTHING;

--CT-1.3.0 changes
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_usedmemory',
 '{
   "name": "TS_hawk_be_getinstancemetrics_usedmemory",
   "description": "Used Memory",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_cpuusage',
 '{
   "name": "TS_hawk_be_getinstancemetrics_cpuusage",
   "description": "CPU Usage",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_clusterlocks',
 '{
   "name": "TS_hawk_be_getinstancemetrics_clusterlocks",
   "description": "Clusterwide Locks held count",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_locallocks',
 '{
   "name": "TS_hawk_be_getinstancemetrics_locallocks",
   "description": "Local Locks held count",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_rtctxlatency',
 '{
   "name": "TS_hawk_be_getinstancemetrics_rtctxlatency",
   "description": "RtcTx Latency",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_rtctxthroughput',
 '{
   "name": "TS_hawk_be_getinstancemetrics_rtctxthroughput",
   "description": "RtcTx Throughput",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_totallocks',
 '{
   "name": "TS_hawk_be_getinstancemetrics_totallocks",
   "description": "Total Locks held count",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707727570404,
   "createdAt": 1707727570404,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_totaleventsprocessed',
 '{
   "name": "TS_hawk_be_getinstancemetrics_totaleventsprocessed",
   "description": "Total Number Of Events Processed",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1718009459691,
   "createdAt": 1718009459691,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_numstaticrules',
 '{
   "name": "TS_hawk_be_getinstancemetrics_numstaticrules",
   "description": "Number of Static Rules",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1718009459691,
   "createdAt": 1718009459691,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancemetrics_totalrulesfired',
 '{
   "name": "TS_hawk_be_getinstancemetrics_totalrulesfired",
   "description": "Total Number of Rules Fired",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1718009459691,
   "createdAt": 1718009459691,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_totalsuccessfultxns',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_totalsuccessfultxns",
   "description": "Total successful transactions",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_totaltimeforsuccessfultxns',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_totaltimeforsuccessfultxns",
   "description": "Total time for successful transactions",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_pendingactions',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_pendingactions",
   "description": "The pending number of actions",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_eventstobeacknowledged',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_eventstobeacknowledged",
   "description": "The number of events pending to be acknowledged",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426954,
   "createdAt": 1707728426954,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_lockstobereleased',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_lockstobereleased",
   "description": "The number of locks waiting to be released",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426954,
   "createdAt": 1707728426954,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_totalcachetxns',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_totalcachetxns",
   "description": "The total number of cache transactions",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_totaldboprs',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_totaldboprs",
   "description": "The total number of database operations completed",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_totalerrors',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_totalerrors",
   "description": "Total number of Errors",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_pendingdbwrites',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_pendingdbwrites",
   "description": "The pending number of Database writes",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426954,
   "createdAt": 1707728426954,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_totaldbqueuewaittime',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_totaldbqueuewaittime",
   "description": "Total Database Queue Wait Time",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426954,
   "createdAt": 1707728426954,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_pendingcachewrites',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_pendingcachewrites",
   "description": "The pending number of Cache Writes.",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426953,
   "createdAt": 1707728426953,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_be_getinstancedetailsmethod_uptime';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancedetailsmethod_uptime',
 '{
   "name": "TS_hawk_be_getinstancedetailsmethod_uptime",
   "description": "Uptime",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "pu",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "deploymentpath",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "jmxport",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "appname",
       "type": "STRING"
     },
     {
       "name": "processid",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "deploymentstatus",
       "type": "STRING"
     },
     {
       "name": "instancetype",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
      "name": "be_home",
      "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "pu",
           "computed": false,
           "expression": "$pu",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "deploymentpath",
           "computed": false,
           "expression": "$deploymentpath",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "jmxport",
           "computed": false,
           "expression": "$jmxport",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "appname",
           "computed": false,
           "expression": "$appname",
           "type": "STRING"
         },
         {
           "name": "processid",
           "computed": false,
           "expression": "$processid",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "deploymentstatus",
           "computed": false,
           "expression": "$deploymentstatus",
           "type": "STRING"
         },
         {
           "name": "instancetype",
           "computed": false,
           "expression": "$instancetype",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
          "name": "be_home",
          "computed": false,
          "expression": "$be_home",
          "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728473139,
   "createdAt": 1707728473139,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_be_getinstancedetailsmethod_cpuusage'; 
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancedetailsmethod_cpuusage',
 '{
   "name": "TS_hawk_be_getinstancedetailsmethod_cpuusage",
   "description": "The current CPU load of this Engine. (A value of 0.0 means none of the CPUs are running, while 1.0 means all CPUs are actively running.)",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "pu",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "deploymentpath",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "jmxport",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "appname",
       "type": "STRING"
     },
     {
       "name": "processid",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "deploymentstatus",
       "type": "STRING"
     },
     {
       "name": "instancetype",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
      "name": "be_home",
      "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "pu",
           "computed": false,
           "expression": "$pu",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "deploymentpath",
           "computed": false,
           "expression": "$deploymentpath",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "jmxport",
           "computed": false,
           "expression": "$jmxport",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "appname",
           "computed": false,
           "expression": "$appname",
           "type": "STRING"
         },
         {
           "name": "processid",
           "computed": false,
           "expression": "$processid",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "deploymentstatus",
           "computed": false,
           "expression": "$deploymentstatus",
           "type": "STRING"
         },
         {
           "name": "instancetype",
           "computed": false,
           "expression": "$instancetype",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
          "name": "be_home",
          "computed": false,
          "expression": "$be_home",
          "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728473140,
   "createdAt": 1707728473140,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_be_getinstancedetailsmethod_usedmemory'; 
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinstancedetailsmethod_usedmemory',
 '{
   "name": "TS_hawk_be_getinstancedetailsmethod_usedmemory",
   "description": "Estimate of the memory used in the JVM, in bytes.",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "pu",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "deploymentpath",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "jmxport",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "appname",
       "type": "STRING"
     },
     {
       "name": "processid",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "deploymentstatus",
       "type": "STRING"
     },
     {
       "name": "instancetype",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
      "name": "be_home",
      "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "pu",
           "computed": false,
           "expression": "$pu",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "deploymentpath",
           "computed": false,
           "expression": "$deploymentpath",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "jmxport",
           "computed": false,
           "expression": "$jmxport",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "appname",
           "computed": false,
           "expression": "$appname",
           "type": "STRING"
         },
         {
           "name": "processid",
           "computed": false,
           "expression": "$processid",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "deploymentstatus",
           "computed": false,
           "expression": "$deploymentstatus",
           "type": "STRING"
         },
         {
           "name": "instancetype",
           "computed": false,
           "expression": "$instancetype",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
          "name": "be_home",
          "computed": false,
          "expression": "$be_home",
          "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728473140,
   "createdAt": 1707728473140,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinferenceagentmetrics_avgtimeforpubtxns',
 '{
   "name": "TS_hawk_be_getinferenceagentmetrics_avgtimeforpubtxns",
   "description": "The average time for publishing the transactions",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728497192,
   "createdAt": 1707728497192,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinferenceagentmetrics_localcachehitratio',
 '{
   "name": "TS_hawk_be_getinferenceagentmetrics_localcachehitratio",
   "description": "Local cache hit ratio",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728497192,
   "createdAt": 1707728497192,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getinferenceagentmetrics_totaltxnspublished',
 '{
   "name": "TS_hawk_be_getinferenceagentmetrics_totaltxnspublished",
   "description": "The total number of transactions published",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728497192,
   "createdAt": 1707728497192,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitythroughput_eventthroughput',
 '{
   "name": "TS_hawk_be_getentitythroughput_eventthroughput",
   "description": "Event Throughput",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "desturi",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "desturi",
           "computed": false,
           "expression": "$desturi",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728582539,
   "createdAt": 1707728582539,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitycachemetrics_totalremoveoprns',
 '{
   "name": "TS_hawk_be_getentitycachemetrics_totalremoveoprns",
   "description": "The total number of removal operations performed on the cache",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728618676,
   "createdAt": 1707728618676,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitycachemetrics_totalputoprns',
 '{
   "name": "TS_hawk_be_getentitycachemetrics_totalputoprns",
   "description": "The total number of put operations",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728618676,
   "createdAt": 1707728618676,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitycachemetrics_avgtimeforgetexec',
 '{
   "name": "TS_hawk_be_getentitycachemetrics_avgtimeforgetexec",
   "description": "The average time to execute gets",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728618676,
   "createdAt": 1707728618676,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitycachemetrics_totalgetoprns',
 '{
   "name": "TS_hawk_be_getentitycachemetrics_totalgetoprns",
   "description": "The total number of get operations",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728618676,
   "createdAt": 1707728618676,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitycachemetrics_avgtimeforremoveexec',
 '{
   "name": "TS_hawk_be_getentitycachemetrics_avgtimeforremoveexec",
   "description": "The average time to execute removals",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728618676,
   "createdAt": 1707728618676,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitycachemetrics_avgtimeforputexec',
 '{
   "name": "TS_hawk_be_getentitycachemetrics_avgtimeforputexec",
   "description": "The average time to execute put",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728618676,
   "createdAt": 1707728618676,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitymetrics_entityavgtimeinrtc',
 '{
   "name": "TS_hawk_be_getentitymetrics_entityavgtimeinrtc",
   "description": "Entity average time in RTC",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728673362,
   "createdAt": 1707728673362,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitymetrics_entityavgtimepostrtc',
 '{
   "name": "TS_hawk_be_getentitymetrics_entityavgtimepostrtc",
   "description": "Entity average time in Post RTC",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728673362,
   "createdAt": 1707728673362,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitymetrics_entityavgtimeprertc',
 '{
   "name": "TS_hawk_be_getentitymetrics_entityavgtimeprertc",
   "description": "Entity average time in Pre RTC",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728673362,
   "createdAt": 1707728673362,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitymetrics_totall1hits',
 '{
   "name": "TS_hawk_be_getentitymetrics_totall1hits",
   "description": "Total hits in L1 Cache",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728673362,
   "createdAt": 1707728673362,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getentitymetrics_totall1misses',
 '{
   "name": "TS_hawk_be_getentitymetrics_totall1misses",
   "description": "The number of misses in L1Cache",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "entityname",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "entityname",
           "computed": false,
           "expression": "$entityname",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728673362,
   "createdAt": 1707728673362,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
 }') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_be_getbeappproperties_hkinfo', '{
  "name": "TS_hawk_be_getbeappproperties_hkinfo",
  "description": "This is a placeholder metric to expose non numeral information.",
  "active": true,
  "sourceFilter": "",
  "columns": [
    {
      "name": "microagent_display_name",
      "type": "STRING"
    },
    {
      "name": "agent_name",
      "type": "STRING"
    },
    {
      "name": "clustername",
      "type": "STRING"
    },
    {
      "name": "agent_os_version",
      "type": "STRING"
    },
    {
      "name": "dpid",
      "type": "STRING"
    },
    {
      "name": "agent_host_name",
      "type": "STRING"
    },
    {
      "name": "agent_ip",
      "type": "STRING"
    },
    {
      "name": "subid",
      "type": "STRING"
    },
    {
      "name": "domain_name",
      "type": "STRING"
    },
    {
      "name": "agent_os_name",
      "type": "STRING"
    },
    {
      "name": "microagent_instance",
      "type": "STRING"
    },
    {
      "name": "propvalue",
      "type": "STRING"
    },
    {
      "name": "microagent_name",
      "type": "STRING"
    },
    {
      "name": "appinstanceid",
      "type": "STRING"
    },
    {
      "name": "propname",
      "type": "STRING"
    },
    {
      "name": "value",
      "type": "FLOAT"
    }
  ],
  "parsingRules": [
    {
      "name": "Rule_1",
      "enabled": true,
      "filter": "",
      "parserProperties": {
        "separator": "|",
        "delimiter": ":",
        "encoding": "UTF-8",
        "parser_type": "keyvalue",
        "beginningRegex": ""
      },
      "columns": [
        {
          "name": "microagent_display_name",
          "computed": false,
          "expression": "$microagent_display_name",
          "type": "STRING"
        },
        {
          "name": "agent_name",
          "computed": false,
          "expression": "$agent_name",
          "type": "STRING"
        },
        {
          "name": "clustername",
          "computed": false,
          "expression": "$clustername",
          "type": "STRING"
        },
        {
          "name": "agent_os_version",
          "computed": false,
          "expression": "$agent_os_version",
          "type": "STRING"
        },
        {
          "name": "dpid",
          "computed": false,
          "expression": "$dpid",
          "type": "STRING"
        },
        {
          "name": "agent_host_name",
          "computed": false,
          "expression": "$agent_host_name",
          "type": "STRING"
        },
        {
          "name": "agent_ip",
          "computed": false,
          "expression": "$agent_ip",
          "type": "STRING"
        },
        {
          "name": "subid",
          "computed": false,
          "expression": "$subid",
          "type": "STRING"
        },
        {
          "name": "domain_name",
          "computed": false,
          "expression": "$domain_name",
          "type": "STRING"
        },
        {
          "name": "agent_os_name",
          "computed": false,
          "expression": "$agent_os_name",
          "type": "STRING"
        },
        {
          "name": "microagent_instance",
          "computed": false,
          "expression": "$microagent_instance",
          "type": "STRING"
        },
        {
          "name": "propvalue",
          "computed": false,
          "expression": "$propvalue",
          "type": "STRING"
        },
        {
          "name": "microagent_name",
          "computed": false,
          "expression": "$microagent_name",
          "type": "STRING"
        },
        {
          "name": "appinstanceid",
          "computed": false,
          "expression": "$appinstanceid",
          "type": "STRING"
        },
        {
          "name": "propname",
          "computed": false,
          "expression": "$propname",
          "type": "STRING"
        },
        {
          "name": "Value",
          "computed": false,
          "expression": "$value",
          "type": "FLOAT"
        }
      ]
    }
  ],
  "lastUpdated": 1707728698488,
  "createdAt": 1707728698488,
  "createdBy": "admin",
  "parentPath": "/User",
  "groupDetails": ""
}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_be_getglobalvariables_hkinfo', '{
  "name": "TS_hawk_be_getglobalvariables_hkinfo",
  "description": "This is a placeholder metric to expose non numeral information.",
  "active": true,
  "sourceFilter": "",
  "columns": [
    {
      "name": "microagent_display_name",
      "type": "STRING"
    },
    {
      "name": "agent_name",
      "type": "STRING"
    },
    {
      "name": "clustername",
      "type": "STRING"
    },
    {
      "name": "agent_os_version",
      "type": "STRING"
    },
    {
      "name": "gvvalue",
      "type": "STRING"
    },
    {
      "name": "dpid",
      "type": "STRING"
    },
    {
      "name": "agent_host_name",
      "type": "STRING"
    },
    {
      "name": "gvname",
      "type": "STRING"
    },
    {
      "name": "agent_ip",
      "type": "STRING"
    },
    {
      "name": "subid",
      "type": "STRING"
    },
    {
      "name": "domain_name",
      "type": "STRING"
    },
    {
      "name": "agent_os_name",
      "type": "STRING"
    },
    {
      "name": "microagent_instance",
      "type": "STRING"
    },
    {
      "name": "microagent_name",
      "type": "STRING"
    },
    {
      "name": "appinstanceid",
      "type": "STRING"
    },
    {
      "name": "value",
      "type": "FLOAT"
    }
  ],
  "parsingRules": [
    {
      "name": "Rule_1",
      "enabled": true,
      "filter": "",
      "parserProperties": {
        "separator": "|",
        "delimiter": ":",
        "encoding": "UTF-8",
        "parser_type": "keyvalue",
        "beginningRegex": ""
      },
      "columns": [
        {
          "name": "microagent_display_name",
          "computed": false,
          "expression": "$microagent_display_name",
          "type": "STRING"
        },
        {
          "name": "agent_name",
          "computed": false,
          "expression": "$agent_name",
          "type": "STRING"
        },
        {
          "name": "clustername",
          "computed": false,
          "expression": "$clustername",
          "type": "STRING"
        },
        {
          "name": "agent_os_version",
          "computed": false,
          "expression": "$agent_os_version",
          "type": "STRING"
        },
        {
          "name": "gvvalue",
          "computed": false,
          "expression": "$gvvalue",
          "type": "STRING"
        },
        {
          "name": "dpid",
          "computed": false,
          "expression": "$dpid",
          "type": "STRING"
        },
        {
          "name": "agent_host_name",
          "computed": false,
          "expression": "$agent_host_name",
          "type": "STRING"
        },
        {
          "name": "gvname",
          "computed": false,
          "expression": "$gvname",
          "type": "STRING"
        },
        {
          "name": "agent_ip",
          "computed": false,
          "expression": "$agent_ip",
          "type": "STRING"
        },
        {
          "name": "subid",
          "computed": false,
          "expression": "$subid",
          "type": "STRING"
        },
        {
          "name": "domain_name",
          "computed": false,
          "expression": "$domain_name",
          "type": "STRING"
        },
        {
          "name": "agent_os_name",
          "computed": false,
          "expression": "$agent_os_name",
          "type": "STRING"
        },
        {
          "name": "microagent_instance",
          "computed": false,
          "expression": "$microagent_instance",
          "type": "STRING"
        },
        {
          "name": "microagent_name",
          "computed": false,
          "expression": "$microagent_name",
          "type": "STRING"
        },
        {
          "name": "appinstanceid",
          "computed": false,
          "expression": "$appinstanceid",
          "type": "STRING"
        },
        {
          "name": "Value",
          "computed": false,
          "expression": "$value",
          "type": "FLOAT"
        }
      ]
    }
  ],
  "lastUpdated": 1707728528436,
  "createdAt": 1707728528436,
  "createdBy": "admin",
  "parentPath": "/User",
  "groupDetails": ""
}') ON CONFLICT DO NOTHING;
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES ('TS_hawk_be_getsystemjvmproperties_hkinfo', '{
  "name": "TS_hawk_be_getsystemjvmproperties_hkinfo",
  "description": "This is a placeholder metric to expose non numeral information.",
  "active": true,
  "sourceFilter": "",
  "columns": [
    {
      "name": "microagent_display_name",
      "type": "STRING"
    },
    {
      "name": "agent_name",
      "type": "STRING"
    },
    {
      "name": "clustername",
      "type": "STRING"
    },
    {
      "name": "agent_os_version",
      "type": "STRING"
    },
    {
      "name": "dpid",
      "type": "STRING"
    },
    {
      "name": "agent_host_name",
      "type": "STRING"
    },
    {
      "name": "agent_ip",
      "type": "STRING"
    },
    {
      "name": "subid",
      "type": "STRING"
    },
    {
      "name": "domain_name",
      "type": "STRING"
    },
    {
      "name": "agent_os_name",
      "type": "STRING"
    },
    {
      "name": "syspropvalue",
      "type": "STRING"
    },
    {
      "name": "syspropname",
      "type": "STRING"
    },
    {
      "name": "microagent_instance",
      "type": "STRING"
    },
    {
      "name": "microagent_name",
      "type": "STRING"
    },
    {
      "name": "appinstanceid",
      "type": "STRING"
    },
    {
      "name": "value",
      "type": "FLOAT"
    }
  ],
  "parsingRules": [
    {
      "name": "Rule_1",
      "enabled": true,
      "filter": "",
      "parserProperties": {
        "separator": "|",
        "delimiter": ":",
        "encoding": "UTF-8",
        "parser_type": "keyvalue",
        "beginningRegex": ""
      },
      "columns": [
        {
          "name": "microagent_display_name",
          "computed": false,
          "expression": "$microagent_display_name",
          "type": "STRING"
        },
        {
          "name": "agent_name",
          "computed": false,
          "expression": "$agent_name",
          "type": "STRING"
        },
        {
          "name": "clustername",
          "computed": false,
          "expression": "$clustername",
          "type": "STRING"
        },
        {
          "name": "agent_os_version",
          "computed": false,
          "expression": "$agent_os_version",
          "type": "STRING"
        },
        {
          "name": "dpid",
          "computed": false,
          "expression": "$dpid",
          "type": "STRING"
        },
        {
          "name": "agent_host_name",
          "computed": false,
          "expression": "$agent_host_name",
          "type": "STRING"
        },
        {
          "name": "agent_ip",
          "computed": false,
          "expression": "$agent_ip",
          "type": "STRING"
        },
        {
          "name": "subid",
          "computed": false,
          "expression": "$subid",
          "type": "STRING"
        },
        {
          "name": "domain_name",
          "computed": false,
          "expression": "$domain_name",
          "type": "STRING"
        },
        {
          "name": "agent_os_name",
          "computed": false,
          "expression": "$agent_os_name",
          "type": "STRING"
        },
        {
          "name": "syspropvalue",
          "computed": false,
          "expression": "$syspropvalue",
          "type": "STRING"
        },
        {
          "name": "syspropname",
          "computed": false,
          "expression": "$syspropname",
          "type": "STRING"
        },
        {
          "name": "microagent_instance",
          "computed": false,
          "expression": "$microagent_instance",
          "type": "STRING"
        },
        {
          "name": "microagent_name",
          "computed": false,
          "expression": "$microagent_name",
          "type": "STRING"
        },
        {
          "name": "appinstanceid",
          "computed": false,
          "expression": "$appinstanceid",
          "type": "STRING"
        },
        {
          "name": "Value",
          "computed": false,
          "expression": "$value",
          "type": "FLOAT"
        }
      ]
    }
  ],
  "lastUpdated": 1707728393509,
  "createdAt": 1707728393509,
  "createdBy": "admin",
  "parentPath": "/User",
  "groupDetails": ""
}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_be_getrtctransactionmanagermetrics_avgdbqueuewaittime';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_avgdbqueuewaittime',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_avgdbqueuewaittime",
   "description": "Average Database Queue Wait Time.",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426955,
   "createdAt": 1707728426955,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
}') ON CONFLICT DO NOTHING;
DELETE FROM redtail_ct_info.datamodel WHERE name = 'TS_hawk_be_getrtctransactionmanagermetrics_avgtimeforsuccessfultxns';
INSERT INTO redtail_ct_info.datamodel (name, datamodel_config) VALUES
('TS_hawk_be_getrtctransactionmanagermetrics_avgtimeforsuccessfultxns',
 '{
   "name": "TS_hawk_be_getrtctransactionmanagermetrics_avgtimeforsuccessfultxns",
   "description": "Average time for successful transactions.",
   "active": true,
   "sourceFilter": "",
   "columns": [
     {
       "name": "microagent_display_name",
       "type": "STRING"
     },
     {
       "name": "agent_name",
       "type": "STRING"
     },
     {
       "name": "clustername",
       "type": "STRING"
     },
     {
       "name": "agent_os_version",
       "type": "STRING"
     },
     {
       "name": "dpid",
       "type": "STRING"
     },
     {
       "name": "agent_host_name",
       "type": "STRING"
     },
     {
       "name": "agent_ip",
       "type": "STRING"
     },
     {
       "name": "subid",
       "type": "STRING"
     },
     {
       "name": "domain_name",
       "type": "STRING"
     },
     {
       "name": "agent_os_name",
       "type": "STRING"
     },
     {
       "name": "microagent_instance",
       "type": "STRING"
     },
     {
       "name": "microagent_name",
       "type": "STRING"
     },
     {
       "name": "appinstanceid",
       "type": "STRING"
     },
     {
       "name": "value",
       "type": "FLOAT"
     }
   ],
   "parsingRules": [
     {
       "name": "Rule_1",
       "enabled": true,
       "filter": "",
       "parserProperties": {
         "separator": "|",
         "delimiter": ":",
         "encoding": "UTF-8",
         "parser_type": "keyvalue",
         "beginningRegex": ""
       },
       "columns": [
         {
           "name": "microagent_display_name",
           "computed": false,
           "expression": "$microagent_display_name",
           "type": "STRING"
         },
         {
           "name": "agent_name",
           "computed": false,
           "expression": "$agent_name",
           "type": "STRING"
         },
         {
           "name": "clustername",
           "computed": false,
           "expression": "$clustername",
           "type": "STRING"
         },
         {
           "name": "agent_os_version",
           "computed": false,
           "expression": "$agent_os_version",
           "type": "STRING"
         },
         {
           "name": "dpid",
           "computed": false,
           "expression": "$dpid",
           "type": "STRING"
         },
         {
           "name": "agent_host_name",
           "computed": false,
           "expression": "$agent_host_name",
           "type": "STRING"
         },
         {
           "name": "agent_ip",
           "computed": false,
           "expression": "$agent_ip",
           "type": "STRING"
         },
         {
           "name": "subid",
           "computed": false,
           "expression": "$subid",
           "type": "STRING"
         },
         {
           "name": "domain_name",
           "computed": false,
           "expression": "$domain_name",
           "type": "STRING"
         },
         {
           "name": "agent_os_name",
           "computed": false,
           "expression": "$agent_os_name",
           "type": "STRING"
         },
         {
           "name": "microagent_instance",
           "computed": false,
           "expression": "$microagent_instance",
           "type": "STRING"
         },
         {
           "name": "microagent_name",
           "computed": false,
           "expression": "$microagent_name",
           "type": "STRING"
         },
         {
           "name": "appinstanceid",
           "computed": false,
           "expression": "$appinstanceid",
           "type": "STRING"
         },
         {
           "name": "Value",
           "computed": false,
           "expression": "$value",
           "type": "FLOAT"
         }
       ]
     }
   ],
   "lastUpdated": 1707728426956,
   "createdAt": 1707728426956,
   "createdBy": "admin",
   "parentPath": "/User",
   "groupDetails": ""
}') ON CONFLICT DO NOTHING;