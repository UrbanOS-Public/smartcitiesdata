defmodule Forklift.Jobs.JsonToOrc do
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement

  def run(dataset_ids) do
    dataset_ids
    |> Enum.map(&Forklift.Datasets.get!/1)
    |> Enum.map(&insert_data/1)
  end

  defp insert_data(%{technical: %{systemName: system_name}} = dataset) do
    Forklift.DataReaderHelper.terminate(dataset)

    query = "insert into #{system_name} select *, date_format(now(), '%Y_%m') as os_partition from #{system_name}__json"

    case PrestigeHelper.execute_query(query) do
      {:ok, _} ->
        truncate_json_table(system_name)
        :ok
      _ ->
        :error
    end
  after
    Forklift.DataReaderHelper.init(dataset)
  end

  defp truncate_json_table(system_name) do
    %{table: system_name <> "__JSON"}
    |> Statement.truncate()
    |> PrestigeHelper.execute_query()
  end
end
