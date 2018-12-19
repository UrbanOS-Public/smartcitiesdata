defmodule DiscoveryApi.Test.MockKyloResponse do
  def feedmgr_response() do
    ~s({"data": [
      { "id": "57eac648-729c-44f5-89f2-d446ce2a4d68",
        "updateDate": "a while back"
      },
      { "id": "14fca5cd-2ddd-46dd-9380-01e9c35c674f",
        "updateDate": "recently"
      }
    ]})
  end
  def metadata_response() do
    ~s([
      {
        "id": "14fca5cd-2ddd-46dd-9380-01e9c35c674f",
        "systemName": "Swiss_Franc_Cotton",
        "displayName": "Swiss Franc Cotton",
        "description": "Neque soluta architecto consequatur earum ipsam molestiae tempore at dolorem. Similique consectetur cum.",
        "owner": "string",
        "state": "ENABLED",
        "createdTime": "2018-11-08T14:57:09.463Z",
        "precondition": {
          "sla": {
            "id": "string",
            "name": "string",
            "description": "string",
            "defaultGroup": {
              "condition": "string",
              "obligations": [
                {
                  "description": "string"
                }
              ]
            },
            "groups": [
              {
                "condition": "string",
                "obligations": [
                  {
                    "description": "string"
                  }
                ]
              }
            ],
            "slaChecks": [
              {
                "id": "string",
                "cronSchedule": "string"
              }
            ],
            "obligationErrors": [
              "string"
            ],
            "slaCheckErrors": [
              "string"
            ],
            "canEdit": false
          }
        },
        "sources": [
          {
            "lastLoadTime": "2018-10-08T14:57:09.463Z",
            "id": "string",
            "datasourceId": "string",
            "datasource": {
              "owner": {
                "displayName": "string",
                "email": "string",
                "enabled": false,
                "groups": [
                  "string"
                ],
                "systemName": "string"
              },
              "allowedActions": {
                "name": "string",
                "actions": [
                  {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "actions": [
                      {}
                    ]
                  }
                ]
              },
              "roleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "feedRoleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "creationTime": "2018-10-08T14:57:09.463Z",
              "id": "string",
              "name": "string",
              "description": "string",
              "encrypted": false,
              "compressed": false,
              "sourceForFeeds": [
                {}
              ],
              "destinationForFeeds": [
                {}
              ]
            }
          }
        ],
        "destinations": [
          {
            "id": "string",
            "fieldsPolicy": {
              "fieldPolicies": [
                {
                  "name": "string",
                  "description": "string",
                  "rule": "string"
                }
              ]
            },
            "feedId": "string",
            "datasourceId": "string",
            "datasource": {
              "owner": {
                "displayName": "string",
                "email": "string",
                "enabled": false,
                "groups": [
                  "string"
                ],
                "systemName": "string"
              },
              "allowedActions": {
                "name": "string",
                "actions": [
                  {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "actions": [
                      {}
                    ]
                  }
                ]
              },
              "roleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "feedRoleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "creationTime": "2018-10-08T14:57:09.464Z",
              "id": "string",
              "name": "string",
              "description": "string",
              "encrypted": false,
              "compressed": false,
              "sourceForFeeds": [
                {}
              ],
              "destinationForFeeds": [
                {}
              ]
            }
          }
        ],
        "properties": {},
        "category": {
          "id": "string",
          "systemName": "string",
          "displayName": "string",
          "description": "string",
          "userProperties": {},
          "collectedUserProperties": "string"
        },
        "currentInitStatus": {
          "state": "PENDING",
          "timestamp": "2018-10-08T14:57:09.464Z"
        },
        "allowIndexing": false,
        "currentHistoryReindexingStatus": {
          "historyReindexingState": "NEVER_RUN",
          "lastModifiedTimestamp": "2018-10-08T14:57:09.464Z"
        },
        "dependentFeeds": [
          {}
        ],
        "dependentFeedIds": [
          "string"
        ],
        "usedByFeeds": [
          {}
        ],
        "usedByFeedIds": [
          "string"
        ],
        "allowedActions": {
          "name": "string",
          "actions": [
            {
              "systemName": "string",
              "title": "string",
              "description": "string",
              "actions": [
                {}
              ]
            }
          ]
        },
        "userProperties": {},
        "collectedUserProperties": "string"
      },
      {
        "id": "57eac648-729c-44f5-89f2-d446ce2a4d68",
        "systemName": "input_invoice",
        "displayName": "input invoice",
        "description": "Quo aspernatur rerum voluptas natus ratione suscipit. Occaecati temporibus quibusdam fugit. Minus consequuntur adipisci. Velit molestias minus ratione expedita. Unde voluptatum distinctio officia voluptatem. Dolorem quibusdam quia et rem harum odio magni inventore.",
        "owner": "string",
        "state": "ENABLED",
        "createdTime": "2018-11-08T14:57:09.463Z",
        "precondition": {
          "sla": {
            "id": "string",
            "name": "string",
            "description": "string",
            "defaultGroup": {
              "condition": "string",
              "obligations": [
                {
                  "description": "string"
                }
              ]
            },
            "groups": [
              {
                "condition": "string",
                "obligations": [
                  {
                    "description": "string"
                  }
                ]
              }
            ],
            "slaChecks": [
              {
                "id": "string",
                "cronSchedule": "string"
              }
            ],
            "obligationErrors": [
              "string"
            ],
            "slaCheckErrors": [
              "string"
            ],
            "canEdit": false
          }
        },
        "sources": [
          {
            "lastLoadTime": "2018-10-08T14:57:09.463Z",
            "id": "string",
            "datasourceId": "string",
            "datasource": {
              "owner": {
                "displayName": "string",
                "email": "string",
                "enabled": false,
                "groups": [
                  "string"
                ],
                "systemName": "string"
              },
              "allowedActions": {
                "name": "string",
                "actions": [
                  {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "actions": [
                      {}
                    ]
                  }
                ]
              },
              "roleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "feedRoleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "creationTime": "2018-10-08T14:57:09.463Z",
              "id": "string",
              "name": "string",
              "description": "string",
              "encrypted": false,
              "compressed": false,
              "sourceForFeeds": [
                {}
              ],
              "destinationForFeeds": [
                {}
              ]
            }
          }
        ],
        "destinations": [
          {
            "id": "string",
            "fieldsPolicy": {
              "fieldPolicies": [
                {
                  "name": "string",
                  "description": "string",
                  "rule": "string"
                }
              ]
            },
            "feedId": "string",
            "datasourceId": "string",
            "datasource": {
              "owner": {
                "displayName": "string",
                "email": "string",
                "enabled": false,
                "groups": [
                  "string"
                ],
                "systemName": "string"
              },
              "allowedActions": {
                "name": "string",
                "actions": [
                  {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "actions": [
                      {}
                    ]
                  }
                ]
              },
              "roleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "feedRoleMemberships": [
                {
                  "role": {
                    "systemName": "string",
                    "title": "string",
                    "description": "string",
                    "allowedActions": {
                      "name": "string",
                      "actions": [
                        {
                          "systemName": "string",
                          "title": "string",
                          "description": "string",
                          "actions": [
                            {}
                          ]
                        }
                      ]
                    }
                  },
                  "users": [
                    {
                      "displayName": "string",
                      "email": "string",
                      "enabled": false,
                      "groups": [
                        "string"
                      ],
                      "systemName": "string"
                    }
                  ],
                  "groups": [
                    {
                      "description": "string",
                      "memberCount": 0,
                      "systemName": "string",
                      "title": "string"
                    }
                  ]
                }
              ],
              "creationTime": "2018-10-08T14:57:09.464Z",
              "id": "string",
              "name": "string",
              "description": "string",
              "encrypted": false,
              "compressed": false,
              "sourceForFeeds": [
                {}
              ],
              "destinationForFeeds": [
                {}
              ]
            }
          }
        ],
        "properties": {},
        "category": {
          "id": "string",
          "systemName": "string",
          "displayName": "string",
          "description": "string",
          "userProperties": {},
          "collectedUserProperties": "string"
        },
        "currentInitStatus": {
          "state": "PENDING",
          "timestamp": "2018-10-08T14:57:09.464Z"
        },
        "allowIndexing": false,
        "currentHistoryReindexingStatus": {
          "historyReindexingState": "NEVER_RUN",
          "lastModifiedTimestamp": "2018-10-08T14:57:09.464Z"
        },
        "dependentFeeds": [
          {}
        ],
        "dependentFeedIds": [
          "string"
        ],
        "usedByFeeds": [
          {}
        ],
        "usedByFeedIds": [
          "string"
        ],
        "allowedActions": {
          "name": "string",
          "actions": [
            {
              "systemName": "string",
              "title": "string",
              "description": "string",
              "actions": [
                {}
              ]
            }
          ]
        },
        "userProperties": {},
        "collectedUserProperties": "string"
      }
  ])
  end
end
