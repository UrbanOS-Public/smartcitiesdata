defmodule Flair.PrestoClient do
  @table_name_timing "operational_stats"
  @table_name_quality "dataset_quality"
  @moduledoc false

  def get_create_timing_table_statement do
    """
    CREATE TABLE IF NOT EXISTS #{@table_name_timing()} (
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

  def get_create_quality_table_statement do
    """
    CREATE TABLE IF NOT EXISTS #{@table_name_quality()} (
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

  #TODO - collapse these into one message
  def generate_timing_statement_from_events(events) do
    events
    |> Enum.map(&values_statement/1)
    |> Enum.join(", ")
    |> create_insert_statement(@table_name_timing)
  end

  def generate_quality_statement_from_events(events) do
    events
    |> Enum.map(&values_statement/1)
    |> Enum.join(", ")
    |> create_insert_statement(@table_name_quality)
  end

  def execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

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

  defp values_statement(map) do
    """
    ('#{map.dataset_id}', #{map.schema_version}, '#{map.field}', #{map.window_start}, #{
      map.window_end
    }, #{map.valid_values}, #{map.records})
    """
    |> String.replace("\n", "")
  end
end
