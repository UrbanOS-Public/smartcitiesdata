defmodule AndiWeb.IngestionLiveView.FormUpdate do
  def send_value(pid, value) do
    send(pid, value)
  end
end
