defmodule Reaper.DataSlurper.Sftp do
  @moduledoc """
  Downloads sftp files as stream to local filesystem
  """
  @behaviour Reaper.DataSlurper
  alias Reaper.DataSlurper

  @impl DataSlurper
  def handle?(url) do
    String.starts_with?(url, "sftp")
  end

  @impl DataSlurper
  def slurp(url, dataset_id, _headers \\ [], _protocol \\ nil) do
    filename = DataSlurper.determine_filename(dataset_id)
    %{host: host, path: path, port: port} = URI.parse(url)

    case connect(host, port, dataset_id) do
      {:ok, connection} ->
        stream_file(connection, path, filename)

      {:error, reason} ->
        raise "Failed calling '" <> url <> "': " <> inspect(reason)
    end
  end

  defp stream_file(connection, path, filename) do
    connection
    |> SftpEx.stream!(path)
    |> Stream.into(File.stream!(filename, [:write]))
    |> Stream.run()

    {:file, filename}
  end

  defp connect(host, port, dataset_id) do
    case Reaper.SecretRetriever.retrieve_dataset_credentials(dataset_id) do
      {:ok, %{"username" => username, "password" => password}} ->
        SftpEx.connect(
          host: to_charlist(host),
          port: port,
          user: to_charlist(username),
          password: to_charlist(password)
        )

      {:ok, _} ->
        {:error, "Dataset credentials are not of the correct type"}

      error ->
        error
    end
  end
end
