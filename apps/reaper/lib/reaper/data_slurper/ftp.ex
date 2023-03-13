defmodule Reaper.DataSlurper.Ftp do
  @moduledoc """
  Downloads sftp files as stream to local filesystem
  """
  @behaviour Reaper.DataSlurper
  alias Reaper.DataSlurper

  @ftp_errors %{
    eclosed: "The session is closed",
    econn: "Connection to the remote server is prematurely closed",
    ehost: "Host is not found, FTP server is not found, or connection is rejected by FTP server",
    epath: "No such file or directory, or directory already exists, or permission denied",
    euser: "Invalid username or password"
  }

  @impl DataSlurper
  def handle?(url) do
    String.starts_with?(url, "ftp")
  end

  @impl DataSlurper
  def slurp(url, ingestion_id, _headers \\ [], _protocol \\ nil, _action \\ nil, _body \\ "") do
    filename = DataSlurper.determine_filename(ingestion_id)
    %{host: host, path: path, port: port} = URI.parse(url)

    with {:ok, pid} <- connect(host, port, ingestion_id),
      {:file, filename} <- stream_file(pid, path, filename) do
      {:file, filename}
    else
      {:error, reason} ->
        raise "Failed calling '" <> url <> "': " <> inspect(reason)
    end
  end

  defp stream_file(pid, path, filename) do
    case :ftp.recv(pid, ~c(#{path}), filename) do
      :ok -> {:file, filename}
      {:error, reason} ->
        {:error, map_ftp_errors(reason)}
    end
  end

  defp connect(host, port, ingestion_id) do
    case Reaper.SecretRetriever.retrieve_ingestion_credentials(ingestion_id) do
      {:ok, %{"username" => username, "password" => password}} ->
        with {:ok, pid} <- :ftp.open(to_charlist(host)),
             :ok <- :ftp.user(pid, to_charlist(username), to_charlist(password)) do
          {:ok, pid}
        else
          {:error, reason} ->
            {:error, "Unable to establish FTP connection: #{map_ftp_errors(reason)}"}
        end

      {:ok, _} -> {:error, "Ingestion credentials are not of the correct type"}

      error ->
        error
    end
  end

  defp map_ftp_errors(reason) do
    Map.get(@ftp_errors, reason, reason)
  end
end
