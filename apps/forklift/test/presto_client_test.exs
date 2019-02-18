defmodule PrestoClientTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DatasetSchema
  alias Forklift.PrestoClient
  alias Prestige

  test "upload_data sends a valid statement to prestige" do
    dataset_id = "placeholder_id"
    schema = %DatasetSchema{
      id: dataset_id,
      columns: [
        {"id", "int"},
        {"name", "string"}
      ]
    }

    allow(Prestige.execute(any(), catalog: "hive", schema: "default"), return: :ok)
    allow(DatasetRegistryServer.get_schema(any()), return: schema)
    allow(Prestige.prefetch(any()), return: :ok)

    expected_statement =
      ~s/insert into placeholder_id (id,name) values (123,'bob'),(234,'cob'),(345,'dob')/

    messages = [
      %{"id" => 123, "name" => "bob"},
      %{"id" => 234, "name" => "cob"},
      %{"id" => 345, "name" => "dob"}
    ]

    PrestoClient.upload_data("placeholder_id", messages)

    assert_called(
      Prestige.execute(expected_statement, catalog: "hive", schema: "default"),
      once()
    )
  end
end
