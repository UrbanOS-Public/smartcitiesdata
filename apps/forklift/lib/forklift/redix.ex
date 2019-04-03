defmodule Forklift.Redix do
  @moduledoc """
  Pooling mechanism for redix
  """

  @pool_size 5

  def child_spec(opts) do
    children =
      for i <- 0..(@pool_size - 1) do
        redix_opts = Keyword.put(opts, :name, :"redix_#{i}")
        Supervisor.child_spec({Redix, redix_opts}, id: {Redix, i})
      end

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one, name: __MODULE__]]}
    }
  end

  def command(command) do
    Redix.command(random_connection(), command)
  end

  def command!(command) do
    Redix.command!(random_connection(), command)
  end

  def pipeline(commands) do
    Redix.pipeline(random_connection(), commands)
  end

  defp random_connection() do
    index = rem(System.unique_integer([:positive]), @pool_size)
    :"redix_#{index}"
  end
end
