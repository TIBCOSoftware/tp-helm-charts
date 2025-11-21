-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 3;

UPDATE TCTA_ROLE SET COMPONENT_LIST = '[{"component": "ui.home", "permission": "RW"},{"component": "ui.transactions", "permission": "RW" },{"component": "ui.connectors", "permission": "RW" },{"component": "ui.settings", "permission": "R" }]' WHERE ROLE_NAME= 'USR';

