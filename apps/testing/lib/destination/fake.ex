defmodule Destination.Fake do
  @moduledoc """
  `Destination.t()` impl for testing.
  """
  @derive Jason.Encoder
  defstruct id: nil,
            start_link: "ok",
            write: "ok"

  def new!(overrides \\ []) do
    case :ets.whereis(__MODULE__) do
      :undefined -> :ets.new(__MODULE__, [:named_table, :public])
      _ -> :ok
    end

    id = id()
    :ets.insert(__MODULE__, {id, self(), nil})

    struct(__MODULE__, Keyword.put(overrides, :id, id))
  end

  defp id do
    Integer.to_string(:rand.uniform(4_294_967_296), 32) <>
      Integer.to_string(:rand.uniform(4_294_967_296), 32)
  end

  defimpl Destination do
    def start_link(%{start_link: "ok", id: id}, _) do
      Process.sleep(10)

      pid = :ets.lookup_element(Destination.Fake, id, 2)
      send(pid, {:destination_start_link, id})

      {:ok, :destination_fake_pid}
    end

    def start_link(%{start_link: error}, _) do
      Ok.error(error)
    end

    def write(%{write: "ok", id: id}, :destination_fake_pid, messages) do
      pid = :ets.lookup_element(Destination.Fake, id, 2)
      send(pid, {:destination_write, messages})

      :ok
    end

    def write(%{write: error, id: id}, :destination_fake_pid, _) do
      pid = :ets.lookup_element(Destination.Fake, id, 2)
      send(pid, {:destination_write, error})
      Ok.error(error)
    end

    def stop(%{id: id}, :destination_fake_pid) do
      pid = :ets.lookup_element(Destination.Fake, id, 2)
      Process.exit(pid, :normal)
      :ok
    end

    def delete(t) do
      pid = :ets.lookup_element(Destination.Fake, t.id, 2)
      send(pid, {:destination_delete, t})
      :ok
    end
  end
end
