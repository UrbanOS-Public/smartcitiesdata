-ifndef(_t_c_l_i_service_types_included).
-define(_t_c_l_i_service_types_included, yeah).

-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V1, 0).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V2, 1).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V3, 2).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V4, 3).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V5, 4).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V6, 5).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V7, 6).
-define(T_C_L_I_SERVICE_TPROTOCOLVERSION_HIVE_CLI_SERVICE_PROTOCOL_V8, 7).

-define(T_C_L_I_SERVICE_TTYPEID_BOOLEAN_TYPE, 0).
-define(T_C_L_I_SERVICE_TTYPEID_TINYINT_TYPE, 1).
-define(T_C_L_I_SERVICE_TTYPEID_SMALLINT_TYPE, 2).
-define(T_C_L_I_SERVICE_TTYPEID_INT_TYPE, 3).
-define(T_C_L_I_SERVICE_TTYPEID_BIGINT_TYPE, 4).
-define(T_C_L_I_SERVICE_TTYPEID_FLOAT_TYPE, 5).
-define(T_C_L_I_SERVICE_TTYPEID_DOUBLE_TYPE, 6).
-define(T_C_L_I_SERVICE_TTYPEID_STRING_TYPE, 7).
-define(T_C_L_I_SERVICE_TTYPEID_TIMESTAMP_TYPE, 8).
-define(T_C_L_I_SERVICE_TTYPEID_BINARY_TYPE, 9).
-define(T_C_L_I_SERVICE_TTYPEID_ARRAY_TYPE, 10).
-define(T_C_L_I_SERVICE_TTYPEID_MAP_TYPE, 11).
-define(T_C_L_I_SERVICE_TTYPEID_STRUCT_TYPE, 12).
-define(T_C_L_I_SERVICE_TTYPEID_UNION_TYPE, 13).
-define(T_C_L_I_SERVICE_TTYPEID_USER_DEFINED_TYPE, 14).
-define(T_C_L_I_SERVICE_TTYPEID_DECIMAL_TYPE, 15).
-define(T_C_L_I_SERVICE_TTYPEID_NULL_TYPE, 16).
-define(T_C_L_I_SERVICE_TTYPEID_DATE_TYPE, 17).
-define(T_C_L_I_SERVICE_TTYPEID_VARCHAR_TYPE, 18).
-define(T_C_L_I_SERVICE_TTYPEID_CHAR_TYPE, 19).
-define(T_C_L_I_SERVICE_TTYPEID_INTERVAL_YEAR_MONTH_TYPE, 20).
-define(T_C_L_I_SERVICE_TTYPEID_INTERVAL_DAY_TIME_TYPE, 21).

-define(T_C_L_I_SERVICE_TSTATUSCODE_SUCCESS_STATUS, 0).
-define(T_C_L_I_SERVICE_TSTATUSCODE_SUCCESS_WITH_INFO_STATUS, 1).
-define(T_C_L_I_SERVICE_TSTATUSCODE_STILL_EXECUTING_STATUS, 2).
-define(T_C_L_I_SERVICE_TSTATUSCODE_ERROR_STATUS, 3).
-define(T_C_L_I_SERVICE_TSTATUSCODE_INVALID_HANDLE_STATUS, 4).

-define(T_C_L_I_SERVICE_TOPERATIONSTATE_INITIALIZED_STATE, 0).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_RUNNING_STATE, 1).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_FINISHED_STATE, 2).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_CANCELED_STATE, 3).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_CLOSED_STATE, 4).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_ERROR_STATE, 5).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_UKNOWN_STATE, 6).
-define(T_C_L_I_SERVICE_TOPERATIONSTATE_PENDING_STATE, 7).

-define(T_C_L_I_SERVICE_TOPERATIONTYPE_EXECUTE_STATEMENT, 0).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_TYPE_INFO, 1).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_CATALOGS, 2).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_SCHEMAS, 3).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_TABLES, 4).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_TABLE_TYPES, 5).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_COLUMNS, 6).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_GET_FUNCTIONS, 7).
-define(T_C_L_I_SERVICE_TOPERATIONTYPE_UNKNOWN, 8).

-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_DRIVER_CONNECTIONS, 0).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_CONCURRENT_ACTIVITIES, 1).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_DATA_SOURCE_NAME, 2).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_FETCH_DIRECTION, 8).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_SERVER_NAME, 13).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_SEARCH_PATTERN_ESCAPE, 14).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_DBMS_NAME, 17).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_DBMS_VER, 18).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_ACCESSIBLE_TABLES, 19).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_ACCESSIBLE_PROCEDURES, 20).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_CURSOR_COMMIT_BEHAVIOR, 23).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_DATA_SOURCE_READ_ONLY, 25).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_DEFAULT_TXN_ISOLATION, 26).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_IDENTIFIER_CASE, 28).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_IDENTIFIER_QUOTE_CHAR, 29).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_COLUMN_NAME_LEN, 30).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_CURSOR_NAME_LEN, 31).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_SCHEMA_NAME_LEN, 32).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_CATALOG_NAME_LEN, 34).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_TABLE_NAME_LEN, 35).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_SCROLL_CONCURRENCY, 43).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_TXN_CAPABLE, 46).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_USER_NAME, 47).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_TXN_ISOLATION_OPTION, 72).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_INTEGRITY, 73).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_GETDATA_EXTENSIONS, 81).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_NULL_COLLATION, 85).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_ALTER_TABLE, 86).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_ORDER_BY_COLUMNS_IN_SELECT, 90).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_SPECIAL_CHARACTERS, 94).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_COLUMNS_IN_GROUP_BY, 97).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_COLUMNS_IN_INDEX, 98).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_COLUMNS_IN_ORDER_BY, 99).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_COLUMNS_IN_SELECT, 100).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_COLUMNS_IN_TABLE, 101).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_INDEX_SIZE, 102).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_ROW_SIZE, 104).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_STATEMENT_LEN, 105).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_TABLES_IN_SELECT, 106).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_USER_NAME_LEN, 107).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_OJ_CAPABILITIES, 115).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_XOPEN_CLI_YEAR, 10000).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_CURSOR_SENSITIVITY, 10001).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_DESCRIBE_PARAMETER, 10002).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_CATALOG_NAME, 10003).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_COLLATION_SEQ, 10004).
-define(T_C_L_I_SERVICE_TGETINFOTYPE_CLI_MAX_IDENTIFIER_LEN, 10005).

-define(T_C_L_I_SERVICE_TFETCHORIENTATION_FETCH_NEXT, 0).
-define(T_C_L_I_SERVICE_TFETCHORIENTATION_FETCH_PRIOR, 1).
-define(T_C_L_I_SERVICE_TFETCHORIENTATION_FETCH_RELATIVE, 2).
-define(T_C_L_I_SERVICE_TFETCHORIENTATION_FETCH_ABSOLUTE, 3).
-define(T_C_L_I_SERVICE_TFETCHORIENTATION_FETCH_FIRST, 4).
-define(T_C_L_I_SERVICE_TFETCHORIENTATION_FETCH_LAST, 5).

%% struct 'TTypeQualifierValue'

-record('TTypeQualifierValue', {'i32Value' :: integer(),
                                'stringValue' :: string() | binary()}).
-type 'TTypeQualifierValue'() :: #'TTypeQualifierValue'{}.

%% struct 'TTypeQualifiers'

-record('TTypeQualifiers', {'qualifiers' = dict:new() :: dict:dict()}).
-type 'TTypeQualifiers'() :: #'TTypeQualifiers'{}.

%% struct 'TPrimitiveTypeEntry'

-record('TPrimitiveTypeEntry', {'type' :: integer(),
                                'typeQualifiers' :: 'TTypeQualifiers'()}).
-type 'TPrimitiveTypeEntry'() :: #'TPrimitiveTypeEntry'{}.

%% struct 'TArrayTypeEntry'

-record('TArrayTypeEntry', {'objectTypePtr' :: integer()}).
-type 'TArrayTypeEntry'() :: #'TArrayTypeEntry'{}.

%% struct 'TMapTypeEntry'

-record('TMapTypeEntry', {'keyTypePtr' :: integer(),
                          'valueTypePtr' :: integer()}).
-type 'TMapTypeEntry'() :: #'TMapTypeEntry'{}.

%% struct 'TStructTypeEntry'

-record('TStructTypeEntry', {'nameToTypePtr' = dict:new() :: dict:dict()}).
-type 'TStructTypeEntry'() :: #'TStructTypeEntry'{}.

%% struct 'TUnionTypeEntry'

-record('TUnionTypeEntry', {'nameToTypePtr' = dict:new() :: dict:dict()}).
-type 'TUnionTypeEntry'() :: #'TUnionTypeEntry'{}.

%% struct 'TUserDefinedTypeEntry'

-record('TUserDefinedTypeEntry', {'typeClassName' :: string() | binary()}).
-type 'TUserDefinedTypeEntry'() :: #'TUserDefinedTypeEntry'{}.

%% struct 'TTypeEntry'

-record('TTypeEntry', {'primitiveEntry' :: 'TPrimitiveTypeEntry'(),
                       'arrayEntry' :: 'TArrayTypeEntry'(),
                       'mapEntry' :: 'TMapTypeEntry'(),
                       'structEntry' :: 'TStructTypeEntry'(),
                       'unionEntry' :: 'TUnionTypeEntry'(),
                       'userDefinedTypeEntry' :: 'TUserDefinedTypeEntry'()}).
-type 'TTypeEntry'() :: #'TTypeEntry'{}.

%% struct 'TTypeDesc'

-record('TTypeDesc', {'types' = [] :: list()}).
-type 'TTypeDesc'() :: #'TTypeDesc'{}.

%% struct 'TColumnDesc'

-record('TColumnDesc', {'columnName' :: string() | binary(),
                        'typeDesc' = #'TTypeDesc'{} :: 'TTypeDesc'(),
                        'position' :: integer(),
                        'comment' :: string() | binary()}).
-type 'TColumnDesc'() :: #'TColumnDesc'{}.

%% struct 'TTableSchema'

-record('TTableSchema', {'columns' = [] :: list()}).
-type 'TTableSchema'() :: #'TTableSchema'{}.

%% struct 'TBoolValue'

-record('TBoolValue', {'value' :: boolean()}).
-type 'TBoolValue'() :: #'TBoolValue'{}.

%% struct 'TByteValue'

-record('TByteValue', {'value' :: integer()}).
-type 'TByteValue'() :: #'TByteValue'{}.

%% struct 'TI16Value'

-record('TI16Value', {'value' :: integer()}).
-type 'TI16Value'() :: #'TI16Value'{}.

%% struct 'TI32Value'

-record('TI32Value', {'value' :: integer()}).
-type 'TI32Value'() :: #'TI32Value'{}.

%% struct 'TI64Value'

-record('TI64Value', {'value' :: integer()}).
-type 'TI64Value'() :: #'TI64Value'{}.

%% struct 'TDoubleValue'

-record('TDoubleValue', {'value' :: float()}).
-type 'TDoubleValue'() :: #'TDoubleValue'{}.

%% struct 'TStringValue'

-record('TStringValue', {'value' :: string() | binary()}).
-type 'TStringValue'() :: #'TStringValue'{}.

%% struct 'TColumnValue'

-record('TColumnValue', {'boolVal' :: 'TBoolValue'(),
                         'byteVal' :: 'TByteValue'(),
                         'i16Val' :: 'TI16Value'(),
                         'i32Val' :: 'TI32Value'(),
                         'i64Val' :: 'TI64Value'(),
                         'doubleVal' :: 'TDoubleValue'(),
                         'stringVal' :: 'TStringValue'()}).
-type 'TColumnValue'() :: #'TColumnValue'{}.

%% struct 'TRow'

-record('TRow', {'colVals' = [] :: list()}).
-type 'TRow'() :: #'TRow'{}.

%% struct 'TBoolColumn'

-record('TBoolColumn', {'values' = [] :: list(),
                        'nulls' :: string() | binary()}).
-type 'TBoolColumn'() :: #'TBoolColumn'{}.

%% struct 'TByteColumn'

-record('TByteColumn', {'values' = [] :: list(),
                        'nulls' :: string() | binary()}).
-type 'TByteColumn'() :: #'TByteColumn'{}.

%% struct 'TI16Column'

-record('TI16Column', {'values' = [] :: list(),
                       'nulls' :: string() | binary()}).
-type 'TI16Column'() :: #'TI16Column'{}.

%% struct 'TI32Column'

-record('TI32Column', {'values' = [] :: list(),
                       'nulls' :: string() | binary()}).
-type 'TI32Column'() :: #'TI32Column'{}.

%% struct 'TI64Column'

-record('TI64Column', {'values' = [] :: list(),
                       'nulls' :: string() | binary()}).
-type 'TI64Column'() :: #'TI64Column'{}.

%% struct 'TDoubleColumn'

-record('TDoubleColumn', {'values' = [] :: list(),
                          'nulls' :: string() | binary()}).
-type 'TDoubleColumn'() :: #'TDoubleColumn'{}.

%% struct 'TStringColumn'

-record('TStringColumn', {'values' = [] :: list(),
                          'nulls' :: string() | binary()}).
-type 'TStringColumn'() :: #'TStringColumn'{}.

%% struct 'TBinaryColumn'

-record('TBinaryColumn', {'values' = [] :: list(),
                          'nulls' :: string() | binary()}).
-type 'TBinaryColumn'() :: #'TBinaryColumn'{}.

%% struct 'TColumn'

-record('TColumn', {'boolVal' :: 'TBoolColumn'(),
                    'byteVal' :: 'TByteColumn'(),
                    'i16Val' :: 'TI16Column'(),
                    'i32Val' :: 'TI32Column'(),
                    'i64Val' :: 'TI64Column'(),
                    'doubleVal' :: 'TDoubleColumn'(),
                    'stringVal' :: 'TStringColumn'(),
                    'binaryVal' :: 'TBinaryColumn'()}).
-type 'TColumn'() :: #'TColumn'{}.

%% struct 'TRowSet'

-record('TRowSet', {'startRowOffset' :: integer(),
                    'rows' = [] :: list(),
                    'columns' :: list()}).
-type 'TRowSet'() :: #'TRowSet'{}.

%% struct 'TStatus'

-record('TStatus', {'statusCode' :: integer(),
                    'infoMessages' :: list(),
                    'sqlState' :: string() | binary(),
                    'errorCode' :: integer(),
                    'errorMessage' :: string() | binary()}).
-type 'TStatus'() :: #'TStatus'{}.

%% struct 'THandleIdentifier'

-record('THandleIdentifier', {'guid' :: string() | binary(),
                              'secret' :: string() | binary()}).
-type 'THandleIdentifier'() :: #'THandleIdentifier'{}.

%% struct 'TSessionHandle'

-record('TSessionHandle', {'sessionId' = #'THandleIdentifier'{} :: 'THandleIdentifier'()}).
-type 'TSessionHandle'() :: #'TSessionHandle'{}.

%% struct 'TOperationHandle'

-record('TOperationHandle', {'operationId' = #'THandleIdentifier'{} :: 'THandleIdentifier'(),
                             'operationType' :: integer(),
                             'hasResultSet' :: boolean(),
                             'modifiedRowCount' :: float()}).
-type 'TOperationHandle'() :: #'TOperationHandle'{}.

%% struct 'TOpenSessionReq'

-record('TOpenSessionReq', {'client_protocol' = 7 :: integer(),
                            'username' :: string() | binary(),
                            'password' :: string() | binary(),
                            'configuration' :: dict:dict()}).
-type 'TOpenSessionReq'() :: #'TOpenSessionReq'{}.

%% struct 'TOpenSessionResp'

-record('TOpenSessionResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                             'serverProtocolVersion' = 7 :: integer(),
                             'sessionHandle' :: 'TSessionHandle'(),
                             'configuration' :: dict:dict()}).
-type 'TOpenSessionResp'() :: #'TOpenSessionResp'{}.

%% struct 'TCloseSessionReq'

-record('TCloseSessionReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'()}).
-type 'TCloseSessionReq'() :: #'TCloseSessionReq'{}.

%% struct 'TCloseSessionResp'

-record('TCloseSessionResp', {'status' = #'TStatus'{} :: 'TStatus'()}).
-type 'TCloseSessionResp'() :: #'TCloseSessionResp'{}.

%% struct 'TGetInfoValue'

-record('TGetInfoValue', {'stringValue' :: string() | binary(),
                          'smallIntValue' :: integer(),
                          'integerBitmask' :: integer(),
                          'integerFlag' :: integer(),
                          'binaryValue' :: integer(),
                          'lenValue' :: integer()}).
-type 'TGetInfoValue'() :: #'TGetInfoValue'{}.

%% struct 'TGetInfoReq'

-record('TGetInfoReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                        'infoType' :: integer()}).
-type 'TGetInfoReq'() :: #'TGetInfoReq'{}.

%% struct 'TGetInfoResp'

-record('TGetInfoResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                         'infoValue' = #'TGetInfoValue'{} :: 'TGetInfoValue'()}).
-type 'TGetInfoResp'() :: #'TGetInfoResp'{}.

%% struct 'TExecuteStatementReq'

-record('TExecuteStatementReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                                 'statement' :: string() | binary(),
                                 'confOverlay' :: dict:dict(),
                                 'runAsync' = false :: boolean()}).
-type 'TExecuteStatementReq'() :: #'TExecuteStatementReq'{}.

%% struct 'TExecuteStatementResp'

-record('TExecuteStatementResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                                  'operationHandle' :: 'TOperationHandle'()}).
-type 'TExecuteStatementResp'() :: #'TExecuteStatementResp'{}.

%% struct 'TGetTypeInfoReq'

-record('TGetTypeInfoReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'()}).
-type 'TGetTypeInfoReq'() :: #'TGetTypeInfoReq'{}.

%% struct 'TGetTypeInfoResp'

-record('TGetTypeInfoResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                             'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetTypeInfoResp'() :: #'TGetTypeInfoResp'{}.

%% struct 'TGetCatalogsReq'

-record('TGetCatalogsReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'()}).
-type 'TGetCatalogsReq'() :: #'TGetCatalogsReq'{}.

%% struct 'TGetCatalogsResp'

-record('TGetCatalogsResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                             'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetCatalogsResp'() :: #'TGetCatalogsResp'{}.

%% struct 'TGetSchemasReq'

-record('TGetSchemasReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                           'catalogName' :: string() | binary(),
                           'schemaName' :: string() | binary()}).
-type 'TGetSchemasReq'() :: #'TGetSchemasReq'{}.

%% struct 'TGetSchemasResp'

-record('TGetSchemasResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                            'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetSchemasResp'() :: #'TGetSchemasResp'{}.

%% struct 'TGetTablesReq'

-record('TGetTablesReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                          'catalogName' :: string() | binary(),
                          'schemaName' :: string() | binary(),
                          'tableName' :: string() | binary(),
                          'tableTypes' :: list()}).
-type 'TGetTablesReq'() :: #'TGetTablesReq'{}.

%% struct 'TGetTablesResp'

-record('TGetTablesResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                           'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetTablesResp'() :: #'TGetTablesResp'{}.

%% struct 'TGetTableTypesReq'

-record('TGetTableTypesReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'()}).
-type 'TGetTableTypesReq'() :: #'TGetTableTypesReq'{}.

%% struct 'TGetTableTypesResp'

-record('TGetTableTypesResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                               'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetTableTypesResp'() :: #'TGetTableTypesResp'{}.

%% struct 'TGetColumnsReq'

-record('TGetColumnsReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                           'catalogName' :: string() | binary(),
                           'schemaName' :: string() | binary(),
                           'tableName' :: string() | binary(),
                           'columnName' :: string() | binary()}).
-type 'TGetColumnsReq'() :: #'TGetColumnsReq'{}.

%% struct 'TGetColumnsResp'

-record('TGetColumnsResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                            'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetColumnsResp'() :: #'TGetColumnsResp'{}.

%% struct 'TGetFunctionsReq'

-record('TGetFunctionsReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                             'catalogName' :: string() | binary(),
                             'schemaName' :: string() | binary(),
                             'functionName' :: string() | binary()}).
-type 'TGetFunctionsReq'() :: #'TGetFunctionsReq'{}.

%% struct 'TGetFunctionsResp'

-record('TGetFunctionsResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                              'operationHandle' :: 'TOperationHandle'()}).
-type 'TGetFunctionsResp'() :: #'TGetFunctionsResp'{}.

%% struct 'TGetOperationStatusReq'

-record('TGetOperationStatusReq', {'operationHandle' = #'TOperationHandle'{} :: 'TOperationHandle'()}).
-type 'TGetOperationStatusReq'() :: #'TGetOperationStatusReq'{}.

%% struct 'TGetOperationStatusResp'

-record('TGetOperationStatusResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                                    'operationState' :: integer(),
                                    'sqlState' :: string() | binary(),
                                    'errorCode' :: integer(),
                                    'errorMessage' :: string() | binary()}).
-type 'TGetOperationStatusResp'() :: #'TGetOperationStatusResp'{}.

%% struct 'TCancelOperationReq'

-record('TCancelOperationReq', {'operationHandle' = #'TOperationHandle'{} :: 'TOperationHandle'()}).
-type 'TCancelOperationReq'() :: #'TCancelOperationReq'{}.

%% struct 'TCancelOperationResp'

-record('TCancelOperationResp', {'status' = #'TStatus'{} :: 'TStatus'()}).
-type 'TCancelOperationResp'() :: #'TCancelOperationResp'{}.

%% struct 'TCloseOperationReq'

-record('TCloseOperationReq', {'operationHandle' = #'TOperationHandle'{} :: 'TOperationHandle'()}).
-type 'TCloseOperationReq'() :: #'TCloseOperationReq'{}.

%% struct 'TCloseOperationResp'

-record('TCloseOperationResp', {'status' = #'TStatus'{} :: 'TStatus'()}).
-type 'TCloseOperationResp'() :: #'TCloseOperationResp'{}.

%% struct 'TGetResultSetMetadataReq'

-record('TGetResultSetMetadataReq', {'operationHandle' = #'TOperationHandle'{} :: 'TOperationHandle'()}).
-type 'TGetResultSetMetadataReq'() :: #'TGetResultSetMetadataReq'{}.

%% struct 'TGetResultSetMetadataResp'

-record('TGetResultSetMetadataResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                                      'schema' :: 'TTableSchema'()}).
-type 'TGetResultSetMetadataResp'() :: #'TGetResultSetMetadataResp'{}.

%% struct 'TFetchResultsReq'

-record('TFetchResultsReq', {'operationHandle' = #'TOperationHandle'{} :: 'TOperationHandle'(),
                             'orientation' = 0 :: integer(),
                             'maxRows' :: integer(),
                             'fetchType' = 0 :: integer()}).
-type 'TFetchResultsReq'() :: #'TFetchResultsReq'{}.

%% struct 'TFetchResultsResp'

-record('TFetchResultsResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                              'hasMoreRows' :: boolean(),
                              'results' :: 'TRowSet'()}).
-type 'TFetchResultsResp'() :: #'TFetchResultsResp'{}.

%% struct 'TGetDelegationTokenReq'

-record('TGetDelegationTokenReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                                   'owner' :: string() | binary(),
                                   'renewer' :: string() | binary()}).
-type 'TGetDelegationTokenReq'() :: #'TGetDelegationTokenReq'{}.

%% struct 'TGetDelegationTokenResp'

-record('TGetDelegationTokenResp', {'status' = #'TStatus'{} :: 'TStatus'(),
                                    'delegationToken' :: string() | binary()}).
-type 'TGetDelegationTokenResp'() :: #'TGetDelegationTokenResp'{}.

%% struct 'TCancelDelegationTokenReq'

-record('TCancelDelegationTokenReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                                      'delegationToken' :: string() | binary()}).
-type 'TCancelDelegationTokenReq'() :: #'TCancelDelegationTokenReq'{}.

%% struct 'TCancelDelegationTokenResp'

-record('TCancelDelegationTokenResp', {'status' = #'TStatus'{} :: 'TStatus'()}).
-type 'TCancelDelegationTokenResp'() :: #'TCancelDelegationTokenResp'{}.

%% struct 'TRenewDelegationTokenReq'

-record('TRenewDelegationTokenReq', {'sessionHandle' = #'TSessionHandle'{} :: 'TSessionHandle'(),
                                     'delegationToken' :: string() | binary()}).
-type 'TRenewDelegationTokenReq'() :: #'TRenewDelegationTokenReq'{}.

%% struct 'TRenewDelegationTokenResp'

-record('TRenewDelegationTokenResp', {'status' = #'TStatus'{} :: 'TStatus'()}).
-type 'TRenewDelegationTokenResp'() :: #'TRenewDelegationTokenResp'{}.

-endif.
