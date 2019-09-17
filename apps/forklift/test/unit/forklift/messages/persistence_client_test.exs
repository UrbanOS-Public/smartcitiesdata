defmodule PersistenceClientTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.Messages.PersistenceClient
  alias Forklift.Datasets.DatasetSchema

  test "upload_data sends a valid statement to prestige" do
    system_name = "placeholder_sys_name"

    schema = %DatasetSchema{
      id: "1234",
      system_name: system_name,
      columns: [
        %{name: "id", type: "int"},
        %{name: "name", type: "string"}
      ]
    }

    allow(Prestige.execute(any()), return: :ok)

    allow(Redix.command(:redix, ["SET", "forklift:last_insert_date:" <> schema.id, any()]), return: :ok)

    allow(Prestige.prefetch(any()), return: [[1]])

    expected_statement =
      ~s/insert into "#{system_name}" ("id","name") values row(123,'bob'),row(234,'cob'),row(345,'dob')/

    messages = [
      %{"id" => 123, "name" => "bob"},
      %{"id" => 234, "name" => "cob"},
      %{"id" => 345, "name" => "dob"}
    ]

    PersistenceClient.upload_data(schema, messages)

    assert_called(
      Prestige.execute(expected_statement),
      once()
    )
  end
end
