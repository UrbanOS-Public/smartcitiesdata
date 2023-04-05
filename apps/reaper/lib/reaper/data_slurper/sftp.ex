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
  def slurp(url, ingestion_id, _headers \\ [], _protocol \\ nil, _action \\ nil, _body \\ "") do
    filename = DataSlurper.determine_filename(ingestion_id)
    %{host: host, path: path, port: port, userinfo: userinfo} = URI.parse(url)

    with [username, password] <- get_sftp_credentials(userinfo),
         {:ok, pid} <- connect(host, username, password, port, ingestion_id),
         {:file, filename} <- stream_file(pid, path, filename) do
      {:file, filename}
    else
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

  defp connect(host, username, password, port, ingestion_id) do
    SftpEx.connect(
      host: to_charlist(host),
      port: port,
      user: to_charlist(username),
      password: to_charlist(password)
    )
  end

  defp get_sftp_credentials(userinfo) do
    case userinfo |> String.split(":") do
      [username, password] -> [username, password]
      _ -> {:error, "Ingestion credentials are not in username:password format"}
    end
  end
end
