-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 2;

UPDATE TCTA_ROLE SET COMPONENT_LIST = '[{"component": "ui.home", "permission": "RW"},{"component": "ui.transactions", "permission": "RW" },{"component": "ui.connectors", "permission": "NONE" },{"component": "ui.settings", "permission": "NONE" }]' WHERE ROLE_NAME= 'USR';

