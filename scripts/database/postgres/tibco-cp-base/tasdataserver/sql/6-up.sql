-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 6;

INSERT INTO TCTA_PROPERTY VALUES ('tcta.webServer.download.file.maxTransactions', 'integer',
                                'Max Transactions',
                                'The number of Transactions per download file Request',
                                '10000', true) ON CONFLICT DO NOTHING;
                                
INSERT INTO TCTA_PROPERTY VALUES ('tcta.dataServer.enable.events.resending', 'boolean',
                                'Resending Event Status', 
                                'By enabling this property, TAS will allow re-sending events. Change of this property needs at most 30 seconds to take effect.',
                                'false', false) ON CONFLICT DO NOTHING;
                                                                                              
ALTER TABLE IF EXISTS TCTA_STATUS
DROP COLUMN IF EXISTS email,
ADD COLUMN IF NOT EXISTS BUSINESS_PROCESS CHARACTER VARYING(128),
ADD COLUMN IF NOT EXISTS GROUP_NAME CHARACTER VARYING(128);

-- Drop a unique index named "UNQ_STATUSNAME_SUBID" if it exists
DROP INDEX IF EXISTS UNQ_STATUSNAME_SUBID;
DROP INDEX IF EXISTS UNQ_STATUSNAME_BUS_SUBID;

CREATE UNIQUE INDEX UNQ_STATUSNAME_BUS_SUBID ON TCTA_STATUS (lower(STATUS_NAME), lower(BUSINESS_PROCESS),TSC_SUB_ID);

DROP TABLE IF EXISTS TCTA_SUB_EMAIL;
CREATE TABLE IF NOT EXISTS TCTA_SUB_EMAIL(
	GROUP_ID        	 CHARACTER VARYING(128) NOT NULL,
	TSC_SUB_ID        	 CHARACTER VARYING(128) NOT NULL,
	GROUP_NAME      	 CHARACTER VARYING(128),
    EMAIL      		 	 CHARACTER VARYING(128),
    CREATE_TS            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    UPDATE_TS            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (GROUP_ID)
);

DROP INDEX IF EXISTS UNQ_GROUPNAME_SUBID;
CREATE UNIQUE INDEX UNQ_GROUPNAME_SUBID ON TCTA_SUB_EMAIL (lower(GROUP_NAME), TSC_SUB_ID);

CREATE TABLE IF NOT EXISTS TCTA_RESEND_EVENTS(
	TAS_EVENT_ID         CHARACTER VARYING(128) NOT NULL,
	TSC_SUB_ID        	 CHARACTER VARYING(128) NOT NULL,
    CREATE_TS            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    EXPIRED_TS           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (TAS_EVENT_ID)
);
