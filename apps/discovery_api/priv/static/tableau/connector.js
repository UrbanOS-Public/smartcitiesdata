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
  json: tableau.dataTypeEnum.geometry
};

var configurableApiBaseUrl = "http://localhost:4000/api/v1/";
var configurableDatasetLimit = "1000000";
var configurableFileTypes = ["CSV", "GEOJSON"];

window.DiscoveryWDCTranslator = {
  setupConnector: _setupConnector,
  getTableSchemas: _buildGetTableSchemas,
  getTableData: _getTableData,
  convertDatasetToTableSchema: _convertDatasetToTableSchema,
  convertDictionaryToColumns: _convertDictionaryToColumns,
  convertDatasetRowToTableRow: _convertDatasetRowToTableRow
};

function getUrlVars() {
  var vars = {};
  window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(m,key,value) {
      vars[key] = value;
  });
  return vars;
}

const vars = getUrlVars()

if (vars["mode"] == "query") {
  window.modeFunctions = {
    getDatasets: _getQueryDataset,
    getData: _getQueryData,
    getDictionary: _getQueryDictionary
  }
} else {
  window.modeFunctions = {
    getDatasets: _getDatasetList,
    getData: _getDatasetData,
    getDictionary: _getDatasetDictionary
  }
}

window.onload = function() {

}

function submit() {
  if (vars["mode"] == "query") {
    tableau.connectionData = document.getElementById("query").value
  }
  _setupConnector(tableau)
  tableau.submit()
}

function _setupConnector(tableauInstance) {
  var connector = tableauInstance.makeConnector();

  connector.getSchema = DiscoveryWDCTranslator.getTableSchemas();
  connector.getData = DiscoveryWDCTranslator.getTableData;

  tableauInstance.registerConnector(connector);
  window.connector = connector

  connector.init = function(initCallback) {
    initCallback();
    // tableauInstance.submit();
  }
}
_setupConnector(tableau)

function _buildGetTableSchemas() {
  console.log("Building schemas", window.modeFunctions)
  return function(schemaCallback) {
    window.modeFunctions.getDatasets()
    .then(_decodeAsJson)
    .then(_extractTableSchemas)
    .then(function(tableSchemaPromises) {
      console.log("Doing all the promises")
      Promise.all(tableSchemaPromises)
        .then(schemaCallback)
    })
    .catch((error) => console.log('nope', error))
  }
}

function _getTableSchemas(schemaCallback) {
  window.modeFunctions.getDatasets()
    .then(_decodeAsJson)
    .then(_extractTableSchemas)
    .then(function(tableSchemaPromises) {
      Promise.all(tableSchemaPromises)
        .then(schemaCallback)
    })
}

function _getTableData(table, doneCallback) {
  window.modeFunctions.getData(table.tableInfo)
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

function _getDatasetList() {
  return fetch(configurableApiBaseUrl + "dataset/search?apiAccessible=true&offset=0&limit=" + configurableDatasetLimit);
}

function _getQueryDataset() {
    return new Promise(
      (resolve, _reject) => {
        console.log('WAT', tableau.connectionData)
        resolve(
          {
            json: function () { return { results: [{ fileTypes: ['CSV'], title: "query", description: tableau.connectionData, id: "query" }] } }
          }
        )
      }
    );
}

function _getDatasetDictionary(dataset) {
  return fetch(configurableApiBaseUrl + "dataset/" + dataset.id + "/dictionary");
}

function _getQueryDictionary(dataset) {
  console.log("schema for 'dataset'", dataset)
  return fetch(configurableApiBaseUrl + "query/describe?_format=json", {method: 'POST', body: dataset.description});
}

function _getDatasetData(dataset) {
  return fetch(configurableApiBaseUrl + "dataset/" + dataset.description + "/query?_format=json")
}

function _getQueryData(dataset) {
  return fetch(configurableApiBaseUrl + "query?_format=json", {method: 'POST', body: dataset.description});
}

function _tableauAcceptableIdentifier(value) {
  return value.trim().replace(/[^a-zA-Z0-9_]/g, "_").toLowerCase()
}

function _decodeAsJson(response) {
  console.log('decoding', response)
  return response.json();
}

function _supportsDesiredFileTypes(dataset) {
  return configurableFileTypes.some(function(desiredFileType) {
    return dataset.fileTypes.includes(desiredFileType);
  })
}

function _extractTableSchemas(response) {
  var datasets = response.results;

  console.log('_extractTableSchemas response', response)
  var extractedSchemas = datasets.filter(_supportsDesiredFileTypes)
    .map(_extractTableSchema)

  return extractedSchemas
}

function _extractTableSchema(dataset) {
  var tableSchema = _convertDatasetToTableSchema(dataset)
  console.log('_extractTableSchema dataset', dataset)

  return window.modeFunctions.getDictionary(dataset)
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
