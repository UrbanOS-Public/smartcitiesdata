defmodule Forklift.Jobs.JobUtils do
  @moduledoc false
  use Retry.Annotation
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  @retries Application.get_env(:forklift, :compaction_retries, 10)
  @backoff Application.get_env(:forklift, :compaction_backoff, 10)

  @retry with: constant_backoff(@backoff) |> Stream.take(@retries)
  def verify_count(table, target_count, message) do
    with {:ok, actual_count} <- PrestigeHelper.count(table),
         {:ok, _} <- check_count(actual_count, target_count) do
      {:ok, actual_count}
    else
      {:error, actual_count} when is_number(actual_count) ->
        {:error,
         "Table #{table} with count #{actual_count} did not match expected record count of #{target_count} while trying to verify that #{
           message
         }"}

      {:error, error} ->
        {:error,
         "Could not verify record count of table #{table} while trying to verify that #{message}: #{inspect(error)}"}
    end
  end

  def get_actual_count_in_table(table, ingestion_id, extract_start) do
      PrestigeHelper.count_query(
        "select count(1) from #{table} where (_ingestion_id = '#{ingestion_id}' and _extraction_start_time = #{
          extract_start
        })"
      )
  end

  def verify_extraction_count_in_table(table, ingestion_id, extract_start, target_count, actual_count, message) do
    IO.inspect(target_count, label: "target")
    IO.inspect(actual_count, label: "actual")
    with {:ok, _} <- check_count(actual_count, target_count) |> IO.inspect(label: "check count") do
      {:ok, actual_count}
    else
      {:error, actual_count} when is_number(actual_count) ->
        {:error,
         "Table #{table} with count #{actual_count} did not match expected record count of #{target_count} while trying to verify that #{
           message
         }"}

      {:error, error} ->
        {:error,
         "Could not verify record count of table #{table} while trying to verify that #{message}: #{inspect(error)}"}
    end
  end

  defp check_count(actual_count, target_count) do
    case actual_count == target_count do
      true ->
        {:ok, actual_count}

      false ->
        {:error, actual_count}
    end
  end
end
