defmodule StreamingMetrics.Hostname do
  @callback get() :: String.t()

  def get() do
    :inet.gethostname()
  end
end
