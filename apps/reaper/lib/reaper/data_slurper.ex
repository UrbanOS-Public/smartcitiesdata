defmodule Reaper.DataSlurper do
  @moduledoc """
  Downloads data to the file system from various sources
  """

  @type url :: String.t()
  @type dataset_id :: String.t()
  @type filename :: String.t()
  @type headers :: list()

  @callback handle?(url()) :: boolean()
  @callback slurp(url(), dataset_id(), headers()) :: {:file, filename()} | no_return()

  @implementations [
    Reaper.DataSlurper.Http,
    Reaper.DataSlurper.Sftp
  ]

  def slurp(url, dataset_id, headers \\ %{}) do
    @implementations
    |> Enum.find(&handle?(&1, url))
    |> apply(:slurp, [url, dataset_id, headers])
  end

  def determine_filename(dataset_id) do
    Application.get_env(:reaper, :download_dir, "") <> dataset_id
  end

  defp handle?(implementation, url) do
    apply(implementation, :handle?, [url])
  end
end
