defmodule Forklift.Jobs.JobUtils do
  use Retry.Annotation
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  @retries Application.get_env(:forklift, :compaction_retries, 10)
  @backoff Application.get_env(:forklift, :compaction_backoff, 10)

  @retry with: constant_backoff(@backoff) |> Stream.take(@retries)
  def verify_count(table, count, message) do
    actual_count = PrestigeHelper.count(table)

    case actual_count == count do
      true ->
        {:ok, actual_count}

      false ->
        {:error,
         "Table #{table} with count #{actual_count} did not match expected record count of #{count} while trying to verify that #{
           message
         }"}
    end
  end
end
