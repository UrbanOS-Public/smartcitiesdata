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

window.DiscoveryWDCTranslator = {
  submit: submit,
  setupConnector: _setupConnector,
  getTableSchemas: _getTableSchemas,
  getTableData: _getTableData,
  convertDatasetToTableSchema: _convertDatasetToTableSchema,
  convertDictionaryToColumns: _convertDictionaryToColumns,
  convertDatasetRowToTableRow: _convertDatasetRowToTableRow
};

window.DiscoveryAuthHandler = {
  login: login,
  logout: logout
}

function login() {
  auth0Client.authorize();
}

function logout() {
  delete tableau.password
  auth0Client.logout();
}

var datasetLimit = "1000000";
var fileTypes = ["CSV", "GEOJSON"];
var apiPath = '/api/v1/'

function submit(mode) {
  var connectionData = {mode: mode}
  if (mode == "query") {
    connectionData.query = document.getElementById("query").value
    if (connectionData.query == "") {
      document.getElementById('error').style.display = 'block';
      return;
    }
  }
  _setConnectionData(connectionData)

  _setupConnector()
  tableau.submit()
}

function _setupConnector() {
  var connector = tableau.makeConnector();

  connector.getSchema = DiscoveryWDCTranslator.getTableSchemas;
  connector.getData = DiscoveryWDCTranslator.getTableData;

  tableau.registerConnector(connector);

  connector.init = function(initCallback) {

    // TODO: this will need to extract the code from the URL and call the token URL to fetch a refresh token
    auth0Client.parseHash({ hash: window.location.hash }, function(err, authResult) {

      if (!err && authResult) {
        tableau.password = authResult.accessToken;  // TODO: this will fetch the refresh token
      } else {
         // TODO: show a message to the user letting them know things didn't work out
      }
    })

    initCallback();
  }
}

_setupConnector()

function _getTableSchemas(schemaCallback) {
  // TODO: fetch access token and send with the requests made below
  _getDatasets()
    .then(_decodeAsJson)
    .then(_extractTableSchemas)
    .then(function(tableSchemaPromises) {
      return Promise.all(tableSchemaPromises)
    })
    .catch(function(error) {tableau.abortWithError(error)})
    .then(schemaCallback)
}

function _getTableData(table, doneCallback) {
  // TODO: fetch access token and send with the requests made below
  _getData(table.tableInfo)
    .then(_decodeAsJson)
    .then(_convertDatasetRowsToTableRows(table.tableInfo))
    .then(table.appendRows)
    .catch(function(error) {tableau.abortWithError(error)})
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
function _getDatasets() {
  return _getMode() == 'query' ? _getQueryInfo() : _getDatasetList()
}
function _getDictionary(dataset) {
  return _getMode() == 'query' ? _getQueryDictionary(dataset) : _getDatasetDictionary(dataset)
}
function _getData(tableInfo) {
  return _getMode() == 'query' ? _getQueryData(tableInfo) : _getDatasetData(tableInfo)
}
function _convertToTableSchema(info) {
  return _getMode() == 'query' ? _convertQueryInfoToTableSchema(info) : _convertDatasetToTableSchema(info)
}
// ---

// Discovery Mode Functions
function _getDatasetList() {
  return fetch(apiPath + "dataset/search?apiAccessible=true&offset=0&limit=" + datasetLimit);
}

function _getDatasetDictionary(dataset) {
  return fetch(apiPath + "dataset/" + dataset.id + "/dictionary");
}

function _getDatasetData(tableInfo) {
  return fetch(apiPath + "dataset/" + tableInfo.description + "/query?_format=json")
}

function _convertDatasetToTableSchema(dataset) {
  return {
    id: _tableauAcceptableIdentifier(dataset.id),
    alias: dataset.title,
    description: dataset.id,
  }
}
// ---

// Query Mode Functions
function _getQueryInfo() {
  return new Promise(function (resolve) {
    resolve({
      ok: true,
      json: function () {
        return {
          results: [{
            fileTypes: ['CSV'],
            query: _getQueryString()
          }]
        }
      }
    })
  })
}

function _getQueryDictionary(queryInfo) {
  return fetch(apiPath + "query/describe?_format=json", {method: 'POST', body: queryInfo.query});
}

function _getQueryData(tableInfo) {
  // Tableau has limited places to store things in the table struct. We use the description to store the query.
  return fetch(apiPath + "query?_format=json", {method: 'POST', body: tableInfo.description});
}

function _convertQueryInfoToTableSchema(queryInfo) {
  return {
    id: "query",
    alias: "query",
    description: queryInfo.query,
  }
}
// ---

function _tableauAcceptableIdentifier(value) {
  return value.trim().replace(/[^a-zA-Z0-9_]/g, "_").toLowerCase()
}

function _decodeAsJson(response) {
  if (!response.ok) {
    throw "Request failed: " + response.status + ' ' + response.statusText;
  }
  return response.json();
}

function _supportsDesiredFileTypes(dataset) {
  return fileTypes.some(function(desiredFileType) {
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
  var tableSchema = _convertToTableSchema(dataset)

  return _getDictionary(dataset)
    .then(_decodeAsJson)
    .then(_convertDictionaryToColumns)
    .then(function(columns) {
      return Object.assign({}, tableSchema, {
        columns: columns
      })
    })
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

function _setConnectionData(data) {
  tableau.connectionData = JSON.stringify(data)
}

function _getMode() { return JSON.parse(tableau.connectionData).mode }
function _getQueryString() { return JSON.parse(tableau.connectionData).query }
