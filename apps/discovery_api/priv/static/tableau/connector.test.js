global.tableau = {
  dataTypeEnum: {
    int: jest.fn(),
    string: jest.fn(),
    float: jest.fn(),
    bool: jest.fn(),
    date: jest.fn(),
    datetime: jest.fn(),
    geometry: jest.fn()
  },
  makeConnector: () => ({}),
  registerConnector: jest.fn(),
  submit: jest.fn(),
  abortWithError: jest.fn(),
  connectionData: "{}"
}
global.fetch = jest.fn()
global.auth0Client = {
  authorize: jest.fn(),
  parseHash: jest.fn(),
  logout: jest.fn()
}
global.config = {
  client_id: 'this-is-an-id',
  auth_domain: 'localhost',
  auth_url: 'http://localhost',
  redirect_uri: 'http://localhost'
}

const connector = require('./connector.js')

describe('Discovery API Tableau Web Data Connector', () => {
  const successfulAccessTokenResponse = {access_token: 'fake-access-token'}

  const datasetTwoDictionaryFromApi = [
    {
      alias: "properties-data",
      dataType: "double",
      description: "properties-data",
      id: "properties_data",
    },
    {
      alias: "feature",
      dataType: "json",
      id: "feature",
      description: "feature"
    }
  ]
  const datasetListFromApi = [{
    id: 'dataset_one',
    alias: 'The first dataset',
    description: "dataset-one",
    columns: [
      {
        alias: "column one",
        dataType: "string",
        description: "column one",
        id: "column_one",
      },
      {
        alias: "column-two",
        dataType: "integer",
        description: "column-two",
        id: "column_two",
      }
    ]
  },
  {
    id: 'dataset_two',
    alias: 'The second dataset',
    description: "dataset two",
    columns: datasetTwoDictionaryFromApi
  }
  ]


  

  beforeEach(() => {
    delete global.tableau.password
  })

  describe('high level tests', () => {
    let registeredConnector
    beforeEach(() => {
      global.tableau.connectionData = "{}"
      global.tableau.registerConnector = (connector) => { registeredConnector = connector }
      document.body.innerHTML = '<div id="login-button" class="clickable login-link" onclick="login()"><span id="login-text">Log In to Access Private Datasets</span></div>'
    })

    const expectedTableSchemaForDatasetOne = {
      id: 'dataset_one',
      alias: 'The first dataset',
      description: 'dataset-one',
      columns: [{
          id: 'column_one',
          alias: 'column one',
          dataType: tableau.dataTypeEnum.string,
          description: 'column one'
        },
        {
          id: 'column_two',
          alias: 'column-two',
          dataType: tableau.dataTypeEnum.int,
          description: 'column-two'
        }
      ]
    }

    const expectedTableSchemaForDatasetTwo = {
      id: 'dataset_two',
      alias: 'The second dataset',
      description: 'dataset two',
      columns: [{
          id: 'properties_data',
          alias: 'properties-data',
          dataType: tableau.dataTypeEnum.float,
          description: 'properties-data'
        },
        {
          id: 'feature',
          alias: 'feature',
          dataType: tableau.dataTypeEnum.geometry,
          description: 'feature'
        }
      ]
    }

    const datasetTwoDataFromApi = [{
        'properties-data': 0.3,
        feature: {
          geometry: {
            coordinates: [1, 2, 3],
            type: 'Polygon'
          },
          type: 'Feature'
        }
      },
      {
        'properties-data': 0.4,
        feature: {
          geometry: {
            coordinates: [
              [4, 5, 6]
            ],
            type: 'MultiPolygon'
          },
          type: 'Feature'
        }
      }
    ]

    const queryDatasetDictionaryFromApi = [
          {
            id: 'column_one',
            alias: 'column one',
            dataType: "string",
            description: 'column one'
          }
        ]

    const expectedTableSchemaForQueryDataset = {
      id: 'query',
      alias: 'query',
      description: 'select * from something',
      columns: [{
          id: 'column_one',
          alias: 'column one',
          dataType: tableau.dataTypeEnum.string,
          description: 'column one'
        }
      ]
    }

    beforeEach(() => {
      DiscoveryWDCTranslator.setupConnector()
    })

    test('the generated connector calls init callback on init', () => {
      const initCallback = jest.fn()

      registeredConnector.init(initCallback)

      expect(initCallback).toHaveBeenCalled()
    })
    test('sets up the connector with a refresh token if a code is found', (done) => {
      mockFetches({
        'token': {body: {refresh_token: 'this-is-a-refresh-token'}}
      })
      history.pushState({}, 'Test Title', '/connector.html?code=bobthecode');

      DiscoveryWDCTranslator.setupConnector()
      registeredConnector.init(() => {
        expect(global.fetch).toHaveBeenCalledWithBodyContaining('token', 'bobthecode')
        expect(global.tableau.password).toBe('this-is-a-refresh-token')
        done()
      })
    })

    test('after fetching the refresh token, clears the code param from the url', (done) => {
      mockFetches({
        'token': {body: {refresh_token: 'this-is-a-refresh-token'}}
      })
      history.pushState({}, 'Test Title', '/connector.html?code=bobtheothercode');

      DiscoveryWDCTranslator.setupConnector()
      registeredConnector.init(() => {
        expect(window.location.search).toBe('')
        done()
      })
    })

    test('after fetching the refresh token, prevents the user from logging in again', (done) => {
      document.body.innerHTML = '<div id="login-button" class="clickable login-link" onclick="login()"><span id="login-text">Log In to Access Private Datasets</span></div>'
      var expectedHtml = '<div id="login-button" class="login-link"><span id="login-text">Logged In</span></div>'
      mockFetches({
        'token': {body: {refresh_token: 'this-is-a-refresh-token'}}
      })
      history.pushState({}, 'Test Title', '/connector.html?code=bobtheotherothercode');

      DiscoveryWDCTranslator.setupConnector()
      registeredConnector.init(() => {
        expect(document.body.innerHTML).toEqual(expectedHtml)
        done()
      })
    })

    test('after failing to fetch the refresh token, shows an error and allows user to login again', (done) => {
      document.body.innerHTML = '<div id="login-button" class="clickable login-link" onclick="login()"><span id="login-text">Log In to Access Private Datasets</span></div><div class="content" id="login-error" style="display:none"><p id="login-error-text" class="error">A log in error occurred.</p></div>'
      var expectedHtml = '<div id="login-button" class="clickable login-link" onclick="login()"><span id="login-text">Log In to Access Private Datasets</span></div><div class="content" id="login-error" style="display: block;"><p id="login-error-text" class="error">Unable to authenticate: Request failed: 500 Real Bad | If you need to access private datasets, contact your data curator.</p></div>'

      mockFetches({
        'token': {ok: false, status: 500, statusText: 'Real Bad'}
      })
      history.pushState({}, 'Test Title', '/connector.html?code=bobtheotherothercode');

      DiscoveryWDCTranslator.setupConnector()
      registeredConnector.init(() => {
        expect(document.body.innerHTML).toEqual(expectedHtml)
        done()
      })
    })

    describe('on submit for discovery mode', () => {
      beforeEach(() => {
        DiscoveryWDCTranslator.submit('discovery')
      })

      test('the generated connector calls init callback and tableau.submit', () => {
        const initCallback = jest.fn()

        registeredConnector.init(initCallback)

        expect(initCallback).toHaveBeenCalled()
        expect(global.tableau.submit).toHaveBeenCalled()
      })

      test('tableau connection data has the specified mode', () => {
        expect(global.tableau.connectionData).toBe("{\"mode\":\"discovery\"}")
      })
    })

    describe('on submit for query mode', () => {
      describe('with a query entered', () => {
        beforeEach(() => {
          document.body.innerHTML = '<textarea id="query">select * from constellation</textarea>'

          DiscoveryWDCTranslator.submit('query')
        })

        test('the generated connector calls init callback and tableau.submit', () => {
          const initCallback = jest.fn()

          registeredConnector.init(initCallback)

          expect(initCallback).toHaveBeenCalled()
          expect(global.tableau.submit).toHaveBeenCalled()
        })

        test('tableau connection data has the specified mode and query', () => {
          expect(global.tableau.connectionData).toBe("{\"mode\":\"query\",\"query\":\"select * from constellation\"}")
        })
      })

      describe('without a query entered', () => {
        beforeEach(() => {
          global.tableau.submit = jest.fn()
          document.body.innerHTML = '<textarea id="query"></textarea><p id="error" style="display:none">Please enter a query.</p>'

          DiscoveryWDCTranslator.submit('query')
        })

        test('the generated connector is not submitted', () => {
          const initCallback = jest.fn()

          registeredConnector.init(initCallback)

          expect(global.tableau.submit).not.toHaveBeenCalled()
        })

        test('the page displays an informative message', () => {
          expect(document.body.innerHTML).toEqual(expect.stringMatching('<p id="error" style="display: block;"'))
        })
      })

    })

    describe('connector.getSchema', () => {
      describe('in data discovery mode', () => {
        const datasetOneDictionaryUrl = `/api/v1/dataset/${datasetListFromApi[0].id}/dictionary`
        const datasetTwoDictionaryUrl = `/api/v1/dataset/${datasetListFromApi[1].id}/dictionary`

        describe('success', () => {
          beforeEach(() => {
            global.tableau.connectionData = JSON.stringify({mode: 'discovery'})
            mockFetches({
              'table_info': {body: datasetListFromApi}
            })
          })

          test('fetches datasets from the search API', (done) => {
            const schemaCallback = jest.fn(() => {
              expect(global.fetch).toHaveBeenCalledWithUrl('/api/v1/dataset/tableau/table_info')

              done()
            })

            registeredConnector.getSchema(schemaCallback)
          })

          test('the generated connector sends table schemas to what will be a tableau-internal callback', (done) => {
            const schemaCallback = jest.fn((tableSchemas) => {
              expect(tableSchemas).toMatchObject([
                expectedTableSchemaForDatasetOne,
                expectedTableSchemaForDatasetTwo
              ])

              done()
            })

            registeredConnector.getSchema(schemaCallback)
          })
        })

        describe('with an access token', () => {
          beforeEach(() => {
            global.tableau.connectionData = JSON.stringify({mode: 'discovery'})
            global.tableau.password = 'herbert'
            mockFetches({
              'token': {body: successfulAccessTokenResponse},
              'dataset/tableau/table_info': {body: datasetListFromApi}
            })
          })

          test('gets an access token using the refresh token before making other requests', (done) => {
            registeredConnector.getSchema(() => {
              const firstCallUrl = global.fetch.mock.calls[0][0];
              expect(firstCallUrl).toContain('token')
              const firstCallParams = global.fetch.mock.calls[0][1];
              expect(firstCallParams.body).toContain('grant_type=refresh_token')
              expect(firstCallParams.body).toContain(`refresh_token=${global.tableau.password}`)

              done()
            })
          })

          test('uses fetched access token for all subsequent calls', (done) => {
            registeredConnector.getSchema(() => {
              expect(global.fetch).toHaveBeenCalledWithHeader('/api/v1/dataset/tableau/table_info', 'Authorization', `Bearer ${successfulAccessTokenResponse.access_token}`)
              
              done()
            })
          })
        })
      })

      describe('in query mode', () => {
        beforeEach(() => {
          global.tableau.connectionData = JSON.stringify({mode: 'query', query: expectedTableSchemaForQueryDataset.description})
          mockFetches({
            "describe": {body: queryDatasetDictionaryFromApi}
          })
        })

        test('fetches dataset dictionaries from the query describe API', (done) => {
          const schemaCallback = jest.fn(() => {
            const firstCallUrl = global.fetch.mock.calls[0][0]
            expect(firstCallUrl).toContain('/api/v1/tableau/query_describe?_format=json')
            const firstCallBody = global.fetch.mock.calls[0][1]
            expect(firstCallBody.body).toEqual(expectedTableSchemaForQueryDataset.description)

            done()
          })

          registeredConnector.getSchema(schemaCallback)
        })

        test('the generated connector sends table schemas to what will be a tableau-internal callback', (done) => {
          const schemaCallback = jest.fn((tableSchemas) => {
            expect(tableSchemas).toEqual([expectedTableSchemaForQueryDataset])

            done()
          })

          registeredConnector.getSchema(schemaCallback)
        })
      })
    })

    describe('connector.getData', () => {
      describe('in data discovery mode', () => {
        const table = {
          appendRows: jest.fn(),
          tableInfo: expectedTableSchemaForDatasetTwo
        }

        const queryUrl = `/api/v1/dataset/${expectedTableSchemaForDatasetTwo.description}/query?_format=json`

        describe('success', () => {
          beforeEach(() => {
            global.tableau.connectionData = JSON.stringify({mode: 'discovery'})
            mockFetches({
              [queryUrl]: {body: datasetTwoDataFromApi}
            })
          })

          test('fetches data from the dataset query API', (done) => {
            const doneCallback = () => {
              expect(global.fetch).toHaveBeenCalledWithUrl(queryUrl)

              done()
            }

            registeredConnector.getData(table, doneCallback)
          })

          test('the generated connector pushes table data to what will be a tableau-internal callback', (done) => {
            const table = {
              appendRows: jest.fn((tableRows) => {
                expect(tableRows).toEqual([
                  [0.3, {
                    coordinates: [1, 2, 3],
                    type: 'Polygon'
                  }],
                  [0.4, {
                    coordinates: [[4, 5, 6]],
                    type: 'MultiPolygon'
                  }]
                ])

                done()
              }),
              tableInfo: expectedTableSchemaForDatasetTwo
            }
            const doneCallback = jest.fn()

            registeredConnector.getData(table, doneCallback)
          })
        })

        describe('failing to fetch data', () => {
          beforeEach(() => {
            global.tableau.connectionData = JSON.stringify({mode: 'discovery'})
            global.tableau.abortWithError.mockReset()
            mockFetches({
              'query': {ok: false, status: 500, statusText: 'Internal Server Error'}
            })
          })

          test('calls the tableau.abortWithError callback', (done) => {
            const doneCallback = () => {
              expect(tableau.abortWithError).toHaveBeenCalledWith('Request failed: 500 Internal Server Error')

              done()
            }

            registeredConnector.getData(table, doneCallback)
          })
        })
      })

      describe('in query mode', () => {
        const query = 'select this from that'

        describe('success', () => {
          beforeEach(() => {
            global.tableau.connectionData = JSON.stringify({mode: 'query', query})
            mockFetches({
              'query': {body: datasetTwoDictionaryFromApi}
            })
          })

          test('fetches data from the free-form query API', (done) => {
            const table = {
              appendRows: jest.fn(),
              tableInfo: {...expectedTableSchemaForDatasetTwo, ...{description: query}}
            }
            const doneCallback = () => {
              const firstCallUrl = global.fetch.mock.calls[0][0]
              expect(firstCallUrl).toBe('/api/v1/query?_format=json')
              const firstCallBody = global.fetch.mock.calls[0][1]
              expect(firstCallBody.body).toEqual(query)

              done()
            }

            registeredConnector.getData(table, doneCallback)
          })
        })

        describe('with an access token', () => {
          beforeEach(() => {
            global.tableau.connectionData = JSON.stringify({mode: 'query', query})
            global.tableau.password = 'calvin'
            mockFetches({
              'token': {body: successfulAccessTokenResponse},
              'query': {body: datasetTwoDictionaryFromApi}
            })
          })

          test('gets an access token using the refresh token before making other requests', (done) => {
            const table = {
              appendRows: jest.fn(),
              tableInfo: {...expectedTableSchemaForDatasetTwo, ...{description: query}}
            }
            const doneCallback = () => {
              const firstCallUrl = global.fetch.mock.calls[0][0];
              expect(firstCallUrl).toContain('token')
              const firstCallParams = global.fetch.mock.calls[0][1];
              expect(firstCallParams.body).toContain('grant_type=refresh_token')
              expect(firstCallParams.body).toContain(`refresh_token=${global.tableau.password}`)
              done()
            }

            registeredConnector.getData(table, doneCallback)
          })

          test('uses fetched access token for all subsequent calls', (done) => {
            const table = {
              appendRows: jest.fn(),
              tableInfo: {...expectedTableSchemaForDatasetTwo, ...{description: query}}
            }
            const doneCallback = () => {
              expect(global.fetch).toHaveBeenCalledWithHeader('query', 'Authorization', `Bearer ${successfulAccessTokenResponse.access_token}`)

              done()
            }

            registeredConnector.getData(table, doneCallback)
          })
        })
      })
    })
  })

  describe('convertDictionaryToColumns', () => {
    describe('given a valid dataset dictionary containing all the field types', () => {
      let columns
      const dictionary = [
        {
          dataType: 'integer'
        },
        {
          dataType: 'long'
        },
        {
          dataType: 'string'
        },
        {
          dataType: 'double'
        },
        {
          dataType: 'float'
        },
        {
          dataType: 'boolean'
        },
        {
          dataType: 'date'
        },
        {
          dataType: 'timestamp'
        },
        {
          dataType: 'json'
        }
      ]
      beforeEach(() => {
        columns = DiscoveryWDCTranslator.convertDictionaryToColumns(dictionary)
      })

      test('converts the dictionary types to WDC dataTypes correctly', () => {
        const columnsWithOnlyTypes = columns.map((column) => (column.dataType))
        expect(columnsWithOnlyTypes).toEqual([
          tableau.dataTypeEnum.int,
          tableau.dataTypeEnum.int,
          tableau.dataTypeEnum.string,
          tableau.dataTypeEnum.float,
          tableau.dataTypeEnum.float,
          tableau.dataTypeEnum.bool,
          tableau.dataTypeEnum.date,
          tableau.dataTypeEnum.datetime,
          tableau.dataTypeEnum.geometry
        ])
      })
    })
  })
  
  describe('convertDatasetRowToTableRow', () => {
    describe('given a valid WDC table and table schema with original ids in the description', () => {
      let tableRow
      const datasetRow = {
        'first-column': 'a',
        'second column': {
          geometry: 'geojson geometry'
        },
        'third_column': 1
      }
      const tableSchema = {
        appendRows: jest.fn(),
        tableInfo: {
          columns: [{
              id: 'first_column',
              description: 'first-column',
              dataType: tableau.dataTypeEnum.string
            },
            {
              id: 'second_column',
              description: 'second column',
              dataType: tableau.dataTypeEnum.geometry
            },
            {
              id: 'third_column',
              description: 'third_column',
              dataType: tableau.dataTypeEnum.int
            }
          ]
        }
      }

      beforeEach(() => {
        const converter = DiscoveryWDCTranslator.convertDatasetRowToTableRow(tableSchema.tableInfo)

        tableRow = converter(datasetRow)
      })

      test('correctly extracts each field value for the row', () => {
        expect(tableRow).toEqual(['a', 'geojson geometry', 1])
      })
    })
  })

  describe('auth', () => {
    test('login calls auth0.authorize', () => {
      DiscoveryAuthHandler.login()

      expect(auth0Client.authorize).toHaveBeenCalled()
    })

    describe('logout', () => {
      test('calls auth0.logout', () => {
        DiscoveryAuthHandler.logout()

        expect(auth0Client.logout).toHaveBeenCalled()
      })

      test('clears the saved token', () => {
        global.tableau.password = "BobTheToken"
        DiscoveryAuthHandler.logout()

        expect(global.tableau.password).toBeFalsy()
      })
    })
  })
})

function mockFetches(responses) {
  global.fetch = jest.fn((url) => {
    const matchingUrl = Object.keys(responses).find(mockedUrl => {
      return url.includes(mockedUrl)
    })
    const response = responses[matchingUrl]
    if (!response) { throw `No response mocked for ${url}` }

    if (response.ok === undefined || response.ok) {
      return Promise.resolve({
        ok: true,
        json: () => (Promise.resolve(response.body))
      })
    } else {
      return Promise.resolve({
        ok: false,
        status: response.status,
        statusText: response.statusText
      })
    }
  })
}

expect.extend({
  toHaveBeenCalledWithUrl(fetchMock, urlFragment) {
    const matchingCalls = fetchMock.mock.calls.filter(call => {
      return call[0].includes(urlFragment)
    })
    const pass = matchingCalls.length > 0
    return {
      pass,
      message: () => { return pass ? '' : `fetch was not called with ${urlFragment}` }
    }
  }
})

expect.extend({
  toHaveBeenCalledWithBodyContaining(fetchMock, urlFragment, bodyFragment) {
    const matchingCalls = fetchMock.mock.calls.filter(call => {
      return call[0].includes(urlFragment)
    }).filter(call => {
      return call[1].body.includes(bodyFragment)
    })
    const pass = matchingCalls.length > 0
    return {
      pass,
      message: () => { return pass ? '' : `fetch was not called with ${bodyFragment}` }
    }
  }
})

expect.extend({
  toHaveBeenCalledWithHeader(fetchMock, urlFragment, headerKey, headerValue) {
    const matchingCalls = fetchMock.mock.calls.filter(call => {
      return call[0].includes(urlFragment)
    }).filter(call => {
      return call[1].headers[headerKey] == headerValue
    })

    const pass = matchingCalls.length > 0
    return {
      pass,
      message: () => { return pass ? '' : `fetch was not called with ${urlFragment}, ${headerKey}: ${headerValue}` }
    }
  }
})
