defmodule Reaper.SftpExtractor do
  @moduledoc """
  Handles data with sourceUrl coming over sftp to
  decodable format.
  """

  def extract(url) do
    %{host: host, path: path, port: port} = URI.parse(url)

    with {:ok, conn} <-
           SftpEx.connect(
             host: to_charlist(host),
             port: port,
             user: to_charlist("username"),
             password: to_charlist("password")
           ),
         data = SftpEx.download(conn, path) do
      {:ok, data}
    else
      error -> error
    end
  end
end
