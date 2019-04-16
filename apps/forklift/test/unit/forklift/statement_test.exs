defmodule StatementTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DatasetSchema
  alias Forklift.Statement

  test "build generates a valid statement when given a schema and data" do
    data = [
      %{id: 1, name: "Fred"},
      %{id: 2, name: "Gred"},
      %{id: 3, name: "Hred"}
    ]

    result = Statement.build(get_schema(), data)

    expected_result = ~s/insert into "rivers" ("id","name") values row(1,'Fred'),row(2,'Gred'),row(3,'Hred')/

    assert result == expected_result
  end

  test "build generates a valid statement when given a schema and data that are not in the same order" do
    schema = get_schema()

    data = [
      %{name: "Iom", id: 9},
      %{name: "Jom", id: 8},
      %{name: "Yom", id: 7}
    ]

    result = Statement.build(schema, data)
    expected_result = ~s/insert into "rivers" ("id","name") values row(9,'Iom'),row(8,'Jom'),row(7,'Yom')/

    assert result == expected_result
  end

  test "escapes single quotes correctly" do
    data = [
      %{id: 9, name: "Nathaniel's test"}
    ]

    result = Statement.build(get_schema(), data)
    expected_result = ~s/insert into "rivers" ("id","name") values row(9,'Nathaniel''s test')/

    assert result == expected_result
  end

  test "inserts null when field is null" do
    data = [
      %{id: 9, name: nil}
    ]

    result = Statement.build(get_schema(), data)
    expected_result = ~s/insert into "rivers" ("id","name") values row(9,null)/

    assert result == expected_result
  end

  test "inserts null when timestamp field is an empty string" do
    schema = %DatasetSchema{
      system_name: "rivers",
      columns: [
        %{name: "id", type: "number"},
        %{name: "date", type: "timestamp"}
      ]
    }

    data = [
      %{id: 9, date: ""}
    ]

    result = Statement.build(schema, data)
    expected_result = ~s/insert into "rivers" ("id","date") values row(9,null)/

    assert result == expected_result
  end

  test "handles empty string values with a type of string" do
    data = [
      %{id: 1, name: "Fred"},
      %{id: 2, name: "Gred"},
      %{id: 3, name: ""}
    ]

    result = Statement.build(get_schema(), data)

    expected_result = ~s/insert into "rivers" ("id","name") values row(1,'Fred'),row(2,'Gred'),row(3,'')/

    assert result == expected_result
  end

  test "build generates a valid statement when given a complex nested schema and complex nested data" do
    nested_data = get_complex_nested_data()

    result = Statement.build(get_complex_nested_schema(), nested_data)

    expected_result =
      ~s|insert into "nested_rivers" ("first_name","age","friend_names","friends","spouse") values row('Joe',10,array['bob','sally'],array[row('Bill','Bunco'),row('Sally','Bosco')],row('Susan','female',row('Joel','12/07/1941')))|

    assert result == expected_result
  end

  test "build generates a valid statement when given a map" do
    schema = %DatasetSchema{
      system_name: "rows_rivers",
      columns: [
        %{name: "first_name", type: "string"},
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"}
          ]
        }
      ]
    }

    data = [
      %{
        first_name: "Bob",
        spouse: %{first_name: "Hred"}
      },
      %{
        first_name: "Rob",
        spouse: %{first_name: "Freda"}
      }
    ]

    result = Statement.build(schema, data)

    expected_result =
      ~s|insert into "rows_rivers" ("first_name","spouse") values row('Bob',row('Hred')),row('Rob',row('Freda'))|

    assert result == expected_result
  end

  test "build generates a valid statement when given nested rows" do
    schema = %DatasetSchema{
      system_name: "rows_rivers",
      columns: [
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{
              name: "next_of_kin",
              type: "map",
              subSchema: [
                %{name: "first_name", type: "string"},
                %{name: "date_of_birth", type: "string"}
              ]
            }
          ]
        }
      ]
    }

    data = [
      %{
        spouse: %{
          first_name: "Georgia",
          next_of_kin: %{
            first_name: "Bimmy",
            date_of_birth: "01/01/1900"
          }
        }
      },
      %{
        spouse: %{
          first_name: "Regina",
          next_of_kin: %{
            first_name: "Jammy",
            date_of_birth: "01/01/1901"
          }
        }
      }
    ]

    result = Statement.build(schema, data)

    expected_result =
      ~s|insert into "rows_rivers" ("spouse") values row(row('Georgia',row('Bimmy','01/01/1900'))),row(row('Regina',row('Jammy','01/01/1901')))|

    assert result == expected_result
  end

  test "build generates a valid statement when given an array" do
    schema = %DatasetSchema{
      system_name: "rows_rivers",
      columns: [
        %{name: "friend_names", type: "list", itemType: "string"}
      ]
    }

    data = [
      %{
        friend_names: ["Sam", "Jonesy"]
      },
      %{
        friend_names: []
      }
    ]

    result = Statement.build(schema, data)

    expected_result = ~s|insert into "rows_rivers" ("friend_names") values row(array['Sam','Jonesy']),row(array[])|

    assert result == expected_result
  end

  test "build generates a valid statement when given a date" do
    schema = %DatasetSchema{
      system_name: "rows_rivers",
      columns: [
        %{name: "date_of_birth", type: "date"}
      ]
    }

    data = [
      %{
        date_of_birth: "1901-01-01"
      },
      %{
        date_of_birth: "1901-01-21"
      }
    ]

    result = Statement.build(schema, data)

    expected_result =
      ~s|insert into "rows_rivers" ("date_of_birth") values row(DATE '1901-01-01'),row(DATE '1901-01-21')|

    assert result == expected_result
  end

  test "build generates a valid statement when given an array of maps" do
    schema = %DatasetSchema{
      system_name: "rows_rivers",
      columns: [
        %{
          name: "friend_groups",
          type: "list",
          itemType: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "last_name", type: "string"}
          ]
        }
      ]
    }

    data = [
      %{
        friend_groups: [
          %{first_name: "Hayley", last_name: "Person"},
          %{first_name: "Jason", last_name: "Doe"}
        ]
      },
      %{
        friend_groups: [
          %{first_name: "Saint-John", last_name: "Johnson"}
        ]
      }
    ]

    result = Statement.build(schema, data)

    expected_result =
      ~s|insert into "rows_rivers" ("friend_groups") values row(array[row('Hayley','Person'),row('Jason','Doe')]),row(array[row('Saint-John','Johnson')])|

    assert result == expected_result
  end

  defp get_schema() do
    %DatasetSchema{
      system_name: "rivers",
      columns: [
        %{name: "id", type: "number"},
        %{name: "name", type: "string"}
      ]
    }
  end

  defp get_complex_nested_schema() do
    %DatasetSchema{
      system_name: "nested_rivers",
      columns: [
        %{name: "first_name", type: "string"},
        %{name: "age", type: "number"},
        %{name: "friend_names", type: "list", itemType: "string"},
        %{
          name: "friends",
          type: "list",
          itemType: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "pet", type: "string"}
          ]
        },
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "gender", type: "string"},
            %{
              name: "next_of_kin",
              type: "map",
              subSchema: [
                %{name: "first_name", type: "string"},
                %{name: "date_of_birth", type: "string"}
              ]
            }
          ]
        }
      ]
    }
  end

  defp get_complex_nested_data() do
    [
      %{
        first_name: "Joe",
        age: 10,
        friend_names: ["bob", "sally"],
        friends: [
          %{first_name: "Bill", pet: "Bunco"},
          %{first_name: "Sally", pet: "Bosco"}
        ],
        spouse: %{
          first_name: "Susan",
          gender: "female",
          next_of_kin: %{
            first_name: "Joel",
            date_of_birth: "12/07/1941"
          }
        }
      }
    ]
  end
end
