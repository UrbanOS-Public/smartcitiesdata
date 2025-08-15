defmodule AuthServiceBehaviour do
  @moduledoc """
  Behaviour for AuthService to enable proper mocking
  """
  
  @callback create_logged_in_user(Plug.Conn.t()) :: {:ok, Plug.Conn.t()} | {:error, any()}
  @callback get_user_info(String.t()) :: {:ok, map()} | {:error, any()}
end