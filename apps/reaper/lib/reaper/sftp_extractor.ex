defmodule Reaper.SftpExtractor do
  @moduledoc """
  Handles data with sourceUrl coming over sftp to
  decodable format.
  """

  def extract(id, url) do
    %{host: host, path: path, port: port} = URI.parse(url)

    with {:ok, %{username: username, password: password}} <- Reaper.CredentialRetriever.retrieve(id),
         {:ok, conn} <-
           SftpEx.connect(
             host: to_charlist(host),
             port: port,
             user: to_charlist(username),
             password: to_charlist(password)
           ),
         [data | _] = SftpEx.download(conn, path) do
      {:ok, data}
    else
      {:ok, _} -> {:error, "Dataset credentials are not of the correct type"}
      error -> error
    end
  end
end
