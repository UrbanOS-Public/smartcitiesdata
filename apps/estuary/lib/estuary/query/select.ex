defmodule Estuary.Query.Select do
  @moduledoc false

  def select_table do
    insert

    events =
      "SELECT author, create_ts, data, type 
    FROM hive.default.event_stream 
    ORDER BY create_ts
    DESC LIMIT 1000"
      |> Prestige.execute(user: "estury", by_names: true)
      |> Prestige.prefetch()

    {:ok, events}
  rescue
    error -> {:error, error}
  end

  defp insert do
    insert_statement = "insert into hive.default.event_stream 
    (author, create_ts, data, type) 
    values('Author', 1234, 'Data', 'Type')"
    Prestige.execute(insert_statement, user: "estury") |> Stream.run()
  end

  #   def compose(config, data) do
  #     columns = config.schema

  #     columns_fragment =
  #       columns
  #       |> Enum.map(&Map.get(&1, :name))
  #       |> Enum.map(&to_string/1)
  #       |> Enum.map(&~s|"#{&1}"|)
  #       |> Enum.join(",")

  #     data_fragment =
  #       data
  #       |> Enum.map(&format_columns(columns, &1))
  #       |> Enum.map(&to_row_string/1)
  #       |> Enum.join(",")

  #     {:ok, ~s|SELECT #{columns_fragment} FROM "#{table}" ORDER BY #{column} "{order}" LIMIT #{limit}|}
  #   rescue
  #     e ->
  #       Logger.error("Unhandled Statement Builder error: #{inspect(e)}")
  #       {:error, e}
  #   end

  #   payload: %{
  #     "columns" => ["author", "create_ts", "data", "type"],
  #     "table" => "event_stream",
  #     "column" => "create_ts",
  #     "order" => "DESC",
  #     "limit" => "1000"
  #   }
end
