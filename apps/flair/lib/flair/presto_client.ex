defmodule Flair.PrestoClient do
  @table_name "operational_stats_3"

  def get_create_table_statement do
    """
    CREATE TABLE IF NOT EXISTS #{table_name()} (
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

  def generate_statement_from_events(events) do
    events
    |> Enum.map(&values_statement/1)
    |> Enum.join(", ")
    |> create_insert_statement()
  end

  def execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  def table_name do
    @table_name
  end

  defp create_insert_statement(values_statement) do
    "INSERT INTO #{table_name()} VALUES #{values_statement}"
  end

  defp values_statement(%{stats: stats} = map) do
    """
    ('#{map.dataset_id}', '#{map.app}','#{map.label}', #{map.timestamp},
     row(#{stats.count},#{stats.min},#{stats.max},#{stats.stdev},#{stats.average}))
    """
    |> String.replace("\n", "")
  end
end
