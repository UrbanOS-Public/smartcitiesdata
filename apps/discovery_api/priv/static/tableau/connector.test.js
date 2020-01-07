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
  registerConnector: jest.fn()
}
global.fetch = jest.fn()

const connector = require('./connector.js')

describe('Discovery API Tableau Web Data Connector', () => {
  describe('high level tests', () => {
    describe('given a page load (by the require/src tag)', () => {
      let registeredConnector
      const tableauInstance = {
        makeConnector: () => ({}),
        registerConnector: (connector) => {
          registeredConnector = connector;
        },
        submit: jest.fn()
      }

      const datasetListFromApi = {
        results: [{
            id: 'dataset-one',
            title: 'The first dataset',
            fileTypes: ['CSV']
          },
          {
            id: 'dataset two',
            title: 'The second dataset',
            fileTypes: ['GEOJSON']
          }
        ]
      }
      const datasetOneDictionaryFromApi = [{
          name: 'Column One',
          type: 'string'
        },
        {
          name: 'column-two',
          type: 'integer'
        }
      ]
      const datasetTwoDictionaryFromApi = [{
          name: 'properties-data',
          type: 'double'
        },
        {
          name: 'feature',
          type: 'json'
        }
      ]
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

      beforeEach(() => {
        DiscoveryWDCTranslator.setupConnector(tableauInstance)
      })

      describe('non-interactive init', () => {
        test('the generated connector calls init callback and tableau.submit on init', () => {
          const initCallback = jest.fn()

          registeredConnector.init(initCallback)

          expect(initCallback).toHaveBeenCalled()
          expect(tableauInstance.submit).toHaveBeenCalled()
        })
      })

      describe('connector.getSchema', () => {
        beforeEach(() => {
          global.fetch.mockReturnValueOnce(mockFetchResponseAsJson(datasetListFromApi))
            .mockReturnValueOnce(mockFetchResponseAsJson(datasetOneDictionaryFromApi))
            .mockReturnValueOnce(mockFetchResponseAsJson(datasetTwoDictionaryFromApi))
        })

        test('the generated connector sends table schemas to what will be a tableau-internal callback', (done) => {
          const schemaCallback = jest.fn((tableSchemas) => {
            expect(tableSchemas).toEqual([
              expectedTableSchemaForDatasetOne,
              expectedTableSchemaForDatasetTwo
            ])

            done()
          })

          registeredConnector.getSchema(schemaCallback)
        })
      })

      describe('connector.getData', () => {
        beforeEach(() => {
          global.fetch.mockReturnValueOnce(mockFetchResponseAsJson(datasetTwoDataFromApi))
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
    })
  })
  describe('convertDictionaryToColumns', () => {
    describe('given a valid dataset dictionary containing all the field types', () => {
      let columns
      const dictionary = [
        {
          name: 'First Column',
          type: 'integer'
        },
        {
          name: 'Second-Column',
          type: 'long'
        },
        {
          name: 'Third#Column',
          type: 'string'
        },
        {
          name: '4th__Column',
          type: 'double'
        },
        {
          name: 'Fifth-C0lumn',
          type: 'float'
        },
        {
          name: '$ixth-Column',
          type: 'boolean'
        },
        {
          name: ' 7venth  Column ',
          type: 'date'
        },
        {
          name: '8th\ncolumn',
          type: 'timestamp'
        },
        {
          name: 'ninthcolumn',
          type: 'json'
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

      test('converts the dictionary field names to WDC friendly ids', () => {
        const columnsWithOnlyIds = columns.map((column) => (column.id))
        expect(columnsWithOnlyIds).toEqual([
          'first_column',
          'second_column',
          'third_column',
          '4th__column',
          'fifth_c0lumn',
          '_ixth_column',
          '7venth__column',
          '8th_column',
          'ninthcolumn'
        ])
      })

      test('puts the original field names in the description field for later use by the data downloader', () => {
        const columnsWithOnlyDescs = columns.map((column) => (column.description))
        expect(columnsWithOnlyDescs).toEqual([
          'first column',
          'second-column',
          'third#column',
          '4th__column',
          'fifth-c0lumn',
          '$ixth-column',
          ' 7venth  column ',
          '8th\ncolumn',
          'ninthcolumn'
        ])
      })

      test('puts the original field names in the alias field so they show up nice in Tableau', () => {
        const columnsWithOnlyAliases = columns.map((column) => (column.alias))

        expect(columnsWithOnlyAliases).toEqual([
          'first column',
          'second-column',
          'third#column',
          '4th__column',
          'fifth-c0lumn',
          '$ixth-column',
          ' 7venth  column ',
          '8th\ncolumn',
          'ninthcolumn'
        ])
      })
    })
  })
  describe('convertDatasetToTableSchema', () => {
    describe('given a valid dataset', () => {
      let tableSchema
      const dataset = {
        id: 'first-dataset',
        title: 'First Dataset'
      }

      beforeEach(() => {
        tableSchema = DiscoveryWDCTranslator.convertDatasetToTableSchema(dataset)
      })

      test('converts dataset id to WDC friendly id', () => {
        expect(tableSchema.id).toEqual('first_dataset')
      })

      test('puts the original dataset id in the description field for later use by the data downloader', () => {
        expect(tableSchema.description).toEqual(dataset.id)
      })

      test('puts the dataset title in the alias field so it shows up nice in Tableau', () => {
        expect(tableSchema.alias).toEqual(dataset.title)
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
})

function mockFetchResponseAsJson(response) {
  return Promise.resolve({
    json: () => (Promise.resolve(response))
  })
}
