defmodule PersistenceClientTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.Messages.PersistenceClient

  test "upload_data sends a valid statement to prestige" do
    allow(Prestige.execute(any()), return: :ok)
    allow(Redix.command(:redix, ["SET", "forklift:last_insert_date:1234", any()]), return: :ok)
    allow(Prestige.prefetch(any()), return: [[1]])

    system_name = "placeholder_sys_name"
    schema = [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
    dataset = TDG.create_dataset(%{id: "1234", technical: %{systemName: system_name, schema: schema}})

    expected_statement =
      ~s/insert into "#{system_name}" ("id","name") values row(123,'bob'),row(234,'cob'),row(345,'dob')/

    messages = [
      %{"id" => 123, "name" => "bob"},
      %{"id" => 234, "name" => "cob"},
      %{"id" => 345, "name" => "dob"}
    ]

    PersistenceClient.upload_data(dataset, messages)

    assert_called(
      Prestige.execute(expected_statement),
      once()
    )
  end
end
