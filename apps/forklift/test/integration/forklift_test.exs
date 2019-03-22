defmodule PersistenceTest do
  use ExUnit.Case
  require Logger
  use Divo

  test "should insert records into Presto" do
    reg_message = Mockaffe.create_message(:registry, :basic)

    technical =
      reg_message.technical
      |> Map.put(:systemName, "Organization1__Dataset2")

    reg_message = Map.put(reg_message, :technical, technical)

    system_name = reg_message.technical.systemName

    "create table #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    Mockaffe.send_to_kafka(reg_message, "dataset-registry")

    %{payload: %{"id" => id, "name" => name}} = data = Mockaffe.create_message(:data, :basic)
    Mockaffe.send_to_kafka(data, "streaming-transformed")

    Patiently.wait_for!(
      prestige_query("select id, name from #{system_name}", [[id, name]]),
      dwell: 1000,
      max_tries: 20
    )
  end

  defp prestige_query(statement, expected) do
    fn ->
      actual =
        statement
        |> Prestige.execute()
        |> Prestige.prefetch()

      Logger.info("Waiting for #{inspect(actual)} to equal #{inspect(expected)}")

      try do
        assert actual == expected
        true
      rescue
        _ -> false
      end
    end
  end
end
