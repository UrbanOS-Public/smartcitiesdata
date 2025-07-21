
defmodule MockDestination do
  defstruct []
end

defimpl Destination, for: MockDestination do
  def start_link(t, context) do
    {:ok, {t, context}}
  end

  def write(t, _server, messages) do
    {:ok, {t, messages}}
  end

  def stop(t, _server) do
    {:ok, t}
  end

  def delete(t) do
    {:ok, t}
  end
end
