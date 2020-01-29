defmodule PaddleWrapper do
  @moduledoc """
  Wrapper class to reconnect to LDAP in case of connection loss
  """

  def get(base: base, filter: filter) do
    with {:error, :ldap_closed} <- Paddle.get(base: base, filter: filter),
         {:ok, _pid} <- Paddle.reconnect() do
      Paddle.get(base: base, filter: filter)
    else
      value -> value
    end
  end

  def get(filter: filter) do
    with {:error, :ldap_closed} <- Paddle.get(filter: filter),
         {:ok, _pid} <- Paddle.reconnect() do
      Paddle.get(filter: filter)
    else
      value -> value
    end
  end

  def authenticate(user, pass) do
    with {:error, {:gen_tcp_error, :enotconn}} <- Paddle.authenticate(user, pass),
         {:ok, _pid} <- Paddle.reconnect() do
      Paddle.authenticate(user, pass)
    else
      value -> value
    end
  end
end
