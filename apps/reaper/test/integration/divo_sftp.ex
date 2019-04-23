defmodule Reaper.DivoSftp do
  @moduledoc """
  Defines a simple sftp server compatible with divo
  for building a docker-compose file.
  """
  @behaviour Divo.Stack

  @impl Divo.Stack
  def gen_stack(envar \\ []) do
    username = Keyword.get(envar, :username, "username")
    password = Keyword.get(envar, :password, "password")
    port = Keyword.get(envar, :port, 2222)

    %{
      sftp: %{
        image: "atmoz/sftp:alpine",
        ports: ["#{port}:22"],
        command: ["#{username}:#{password}:1001::upload"]
      }
    }
  end
end
