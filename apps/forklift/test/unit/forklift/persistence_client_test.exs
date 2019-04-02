defmodule PersistenceClientTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.{DatasetSchema, PersistenceClient, DatasetRegistryServer}

  test "upload_data sends a valid statement to prestige" do
    system_name = "placeholder_sys_name"

    schema = %DatasetSchema{
      id: "1234",
      system_name: system_name,
      columns: [
        {"id", "int"},
        {"name", "string"}
      ]
    }

    allow(Prestige.execute(any()), return: :ok)

    allow Redix.command(any(), ["SET", "forklift:last_insert_date:" <> schema.id, any()]), return: :ok

    allow(DatasetRegistryServer.get_schema(any()), return: schema)
    allow(Prestige.prefetch(any()), return: :ok)

    expected_statement = ~s/insert into "#{system_name}" ("id","name") values (123,'bob'),(234,'cob'),(345,'dob')/

    messages = [
      %{"id" => 123, "name" => "bob"},
      %{"id" => 234, "name" => "cob"},
      %{"id" => 345, "name" => "dob"}
    ]

    PersistenceClient.upload_data(schema.id, messages)

    assert_called(
      Prestige.execute(expected_statement),
      once()
    )
  end
end
