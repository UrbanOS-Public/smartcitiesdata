var dataMap = {
  integer: tableau.dataTypeEnum.int,
  long: tableau.dataTypeEnum.int,
  string: tableau.dataTypeEnum.string,
  decimal: tableau.dataTypeEnum.float,
  double: tableau.dataTypeEnum.float,
  float: tableau.dataTypeEnum.float,
  boolean: tableau.dataTypeEnum.bool,
  date: tableau.dataTypeEnum.date,
  timestamp: tableau.dataTypeEnum.datetime,
  json: tableau.dataTypeEnum.geometry,
  nested: tableau.dataTypeEnum.string
};

var configurableApiBaseUrl = "http://localhost:4000/api/v1/";
var configurableDatasetLimit = "1000000";
var configurableFileTypes = ["CSV", "GEOJSON"];

window.DiscoveryWDCTranslator = {
  submit: submit,
  setupConnector: _setupConnector,
  getTableSchemas: _getTableSchemas,
  getTableData: _getTableData,
  convertDatasetToTableSchema: _convertDatasetToTableSchema,
  convertDictionaryToColumns: _convertDictionaryToColumns,
  convertDatasetRowToTableRow: _convertDatasetRowToTableRow
};

function submit(tableauInstance, mode) {
  connectionData = {mode}
  if (mode == "query") {
    connectionData.query = document.getElementById("query").value
  }
  _setConnectionData(connectionData, tableauInstance)

  _setupConnector(tableauInstance)
  tableauInstance.submit()
}

function _setupConnector(tableauInstance) {
  var connector = tableauInstance.makeConnector();

  connector.getSchema = DiscoveryWDCTranslator.getTableSchemas;
  connector.getData = DiscoveryWDCTranslator.getTableData;

  tableauInstance.registerConnector(connector);

  connector.init = function(initCallback) {
    initCallback();
  }
}
_setupConnector(tableau)

function _getTableSchemas(schemaCallback) {
  getDatasets(JSON.parse(tableau.connectionData).mode)
    .then(_decodeAsJson)
    .then(_extractTableSchemas)
    .then(function(tableSchemaPromises) {
      Promise.all(tableSchemaPromises)
        .then(schemaCallback)
    })
}

function _getTableData(table, doneCallback) {
  getData(JSON.parse(tableau.connectionData).mode, table.tableInfo)
    .then(_decodeAsJson)
    .then(_convertDatasetRowsToTableRows(table.tableInfo))
    .then(table.appendRows)
    .then(doneCallback)
}

function _convertDatasetRowsToTableRows(tableInfo) {
  return function(datasetData) {
    return datasetData.map(_convertDatasetRowToTableRow(tableInfo));
  }
}

function _convertDatasetRowToTableRow(tableInfo) {
  return function(row) {
    return tableInfo.columns.map(function(column) {
      if (column.dataType == tableau.dataTypeEnum.geometry) {
        return row[column.description].geometry;
      } else {
        return row[column.description];
      }
    });
  }
}

// Mode selectors
const getDatasets = (mode) => {
  return mode == 'query' ? _getQueryDataset() : _getDatasetList()
}
const getDictionary = (mode, dataset) => {
  return mode == 'query' ? _getQueryDictionary(dataset) : _getDatasetDictionary(dataset)
}
const getData = (mode, table) => {
  return mode == 'query' ? _getQueryData(table) : _getDatasetData(table)
}

// Discovery Mode Functions
function _getDatasetList() {
  return fetch(configurableApiBaseUrl + "dataset/search?apiAccessible=true&offset=0&limit=" + configurableDatasetLimit);
}

function _getDatasetDictionary(dataset) {
  return fetch(configurableApiBaseUrl + "dataset/" + dataset.id + "/dictionary");
}

function _getDatasetData(dataset) {
  return fetch(configurableApiBaseUrl + "dataset/" + dataset.description + "/query?_format=json")
}
// ---

// Query Mode Functions
function _getQueryDataset() {
  return new Promise(
    (resolve, _reject) => {
      resolve(
        {
          json: function () { return { results: [{ fileTypes: ['CSV'], title: "query", description: JSON.parse(tableau.connectionData).query, id: "query" }] } }
        }
      )
    }
  );
}

function _getQueryDictionary(dataset) {
  return fetch(configurableApiBaseUrl + "query/describe?_format=json", {method: 'POST', body: dataset.description});
}

function _getQueryData(dataset) {
  return fetch(configurableApiBaseUrl + "query?_format=json", {method: 'POST', body: dataset.description});
}
// ---

function _tableauAcceptableIdentifier(value) {
  return value.trim().replace(/[^a-zA-Z0-9_]/g, "_").toLowerCase()
}

function _decodeAsJson(response) {
  return response.json();
}

function _supportsDesiredFileTypes(dataset) {
  return configurableFileTypes.some(function(desiredFileType) {
    return dataset.fileTypes.includes(desiredFileType);
  })
}

function _extractTableSchemas(response) {
  var datasets = response.results;

  var extractedSchemas = datasets.filter(_supportsDesiredFileTypes)
    .map(_extractTableSchema)

  return extractedSchemas
}

function _extractTableSchema(dataset) {
  var tableSchema = _convertDatasetToTableSchema(dataset)

  return getDictionary(JSON.parse(tableau.connectionData).mode, dataset)
    .then(_decodeAsJson)
    .then(_convertDictionaryToColumns)
    .then(function(columns) {
      return Object.assign({}, tableSchema, {
        columns: columns
      })
    })
}

function _convertDatasetToTableSchema(dataset) {
  return {
    id: _tableauAcceptableIdentifier(dataset.id),
    alias: dataset.title,
    description: dataset.id,
  }
}

function _convertDictionaryToColumns(dictionary) {
  return dictionary.map(function(columnSpec) {
    return {
      id: _tableauAcceptableIdentifier(columnSpec.name),
      alias: columnSpec.name.toLowerCase(),
      description: columnSpec.name.toLowerCase(),
      dataType: dataMap[columnSpec.type]
    }
  })
}

function _setConnectionData(data, tableauInstance) {
  tableauInstance.connectionData = JSON.stringify(data)
}
