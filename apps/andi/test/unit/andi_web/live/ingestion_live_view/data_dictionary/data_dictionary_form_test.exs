defmodule AndiWeb.IngestionLiveView.DataDictionaryFormTest do
  alias AndiWeb.IngestionLiveView.DataDictionaryForm
  use ExUnit.Case

  describe "add field" do
    test "adds updated field to empty schema" do
      updated_field = %{
        id: "testUpdatedId",
        name: "string1",
        sequence: 1,
        subSchema: [],
        type: "string"
      }

      schema = []

      expected_schema = [
        %{
          id: "testUpdatedId",
          name: "string1",
          sequence: 1,
          subSchema: [],
          type: "string"
        }
      ]

      schema_result = DataDictionaryForm.add_field(updated_field, schema)

      assert schema_result == expected_schema
    end

    test "adds updated field to schema" do
      updated_field = %{
        id: "testUpdatedId",
        name: "string1",
        sequence: 1,
        subSchema: [],
        type: "string"
      }

      schema = [
        %{
          id: "testSchemaId",
          name: "string",
          sequence: 0,
          subSchema: [],
          type: "string",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "string",
          sequence: 0,
          subSchema: [],
          type: "string",
        },
        %{
          id: "testUpdatedId",
          name: "string1",
          sequence: 1,
          subSchema: [],
          type: "string"
        }
      ]

      schema_result = DataDictionaryForm.add_field(updated_field, schema)

      assert schema_result == expected_schema
    end

    test "adds updated field to sub-schema" do
      updated_field = %{
        id: "testUpdatedId",
        parent_id: "testSchemaId",
        name: "string1",
        sequence: 1,
        subSchema: [],
        type: "string"
      }

      schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [],
          type: "list",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [updated_field],
          type: "list",
        }
      ]

      schema_result = DataDictionaryForm.add_field(updated_field, schema)

      assert schema_result == expected_schema
    end

    test "adds updated_field to nested schema" do
      updated_field = %{
        id: "testUpdatedId",
        parent_id: "testNestedId2",
        name: "string1",
        sequence: 1,
        type: "string"
      }

      schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [updated_field],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      schema_result = DataDictionaryForm.add_field(updated_field, schema)

      assert schema_result == expected_schema
    end

    test "adds updated_field to nested schema with siblings" do
      updated_field = %{
        id: "testUpdatedId",
        parent_id: "testNestedId2",
        name: "string2",
        sequence: 1,
        type: "string"
      }

      schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [
                    %{
                      id: "testExistingId1",
                      parent_id: "testNestedId2",
                      name: "string1",
                      sequence: 1,
                      subSchema: [],
                      type: "string"
                    }
                  ],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [
                    %{
                      id: "testExistingId1",
                      parent_id: "testNestedId2",
                      name: "string1",
                      sequence: 1,
                      subSchema: [],
                      type: "string"
                    },
                    updated_field
                  ],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      schema_result = DataDictionaryForm.add_field(updated_field, schema)

      assert schema_result == expected_schema
    end
  end

  describe "remove field" do
    test "removes field from schema" do
      schema = [
        %{
          id: "testSchemaId",
          name: "string",
          sequence: 0,
          subSchema: [],
          type: "string",
        }
      ]

      expected_schema = []

      schema_result = DataDictionaryForm.remove_field(schema, "testSchemaId")

      assert schema_result == expected_schema
    end

    test "removes field from sub-schema" do
      schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testSubSchemaId",
              name: "string1",
              sequence: 0,
              subSchema: [],
              type: "string",
            }
          ],
          type: "list",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [],
          type: "list",
        }
      ]

      schema_result = DataDictionaryForm.remove_field(schema, "testSubSchemaId")

      assert schema_result == expected_schema
    end

    test "removes field from nested sub-schema" do
      schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [
                    %{
                      id: "testNestedId3",
                      parent_id: "testNestedId2",
                      name: "string1",
                      sequence: 1,
                      subSchema: [],
                      type: "string"
                    }
                  ],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      schema_result = DataDictionaryForm.remove_field(schema, "testNestedId3")

      assert schema_result == expected_schema
    end

    test "adds updated_field to nested schema with siblings" do
      schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [
                    %{
                      id: "testExistingId1",
                      parent_id: "testNestedId2",
                      name: "string1",
                      sequence: 1,
                      subSchema: [],
                      type: "string"
                    },
                    %{
                      id: "testExistingId2",
                      parent_id: "testNestedId2",
                      name: "string2",
                      sequence: 1,
                      subSchema: [],
                      type: "string"
                    }
                  ],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      expected_schema = [
        %{
          id: "testSchemaId",
          name: "list1",
          sequence: 0,
          subSchema: [
            %{
              id: "testNestedId",
              parent_id: "testSchemaId",
              name: "list2",
              sequence: 1,
              subSchema: [
                %{
                  id: "testNestedId2",
                  parent_id: "testNestedId",
                  name: "list3",
                  sequence: 1,
                  subSchema: [
                    %{
                      id: "testExistingId1",
                      parent_id: "testNestedId2",
                      name: "string1",
                      sequence: 1,
                      subSchema: [],
                      type: "string"
                    }
                  ],
                  type: "list"
                }
              ],
              type: "list"
            }
          ],
          type: "list",
        }
      ]

      schema_result = DataDictionaryForm.remove_field(schema, "testExistingId2")

      assert schema_result == expected_schema
    end
  end
end
