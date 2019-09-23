defmodule Flair.PrestoClient do
  @moduledoc """
  Presto Client creates our presto tables and converts the events it receives into the correct presto insert statements. It then executes those insert statement.
  """

  @table_name_timing Application.get_env(:flair, :table_name_timing, "operational_stats")

  @doc """
  Generates the create table statement used to create the timing table within Presto.
  By default the table name will be 'operational_stats' but can be configured with
  ```
  config :flair,
    table_name_timing: "operational_stats"
  ```
  """
  @spec get_create_timing_table_statement() :: String.t()
  def get_create_timing_table_statement do
    """
    CREATE TABLE IF NOT EXISTS #{@table_name_timing} (
      dataset_id varchar,
      app varchar,
      label varchar,
      timestamp bigint,
      stats row(
        count bigint,
        min double,
        max double,
        std double,
        average double
      )
    )
    """
  end

  @doc """
  Creates a Presto insert statement from a list of dataset timing events.
  """
  @spec generate_statement_from_events(list(map())) :: String.t()
  def generate_statement_from_events(events) do
    table_name = get_table(events)

    events
    |> Enum.map(&values_statement/1)
    |> Enum.join(", ")
    |> create_insert_statement(table_name)
  end

  @doc """
  Executes any valid Presto query.
  """
  @spec execute(String.t()) :: list(list())
  def execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  defp get_table(_events), do: @table_name_timing

  defp create_insert_statement(values_statement, table_name) do
    "INSERT INTO #{table_name} VALUES #{values_statement}"
  end

  defp values_statement(%{stats: stats} = map) do
    """
    ('#{map.dataset_id}', '#{map.app}', '#{map.label}', #{map.timestamp},
     row(#{stats.count},#{stats.min},#{stats.max},#{stats.stdev},#{stats.average}))
    """
    |> String.replace("\n", "")
  end
end
