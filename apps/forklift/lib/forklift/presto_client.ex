defmodule Forklift.PrestoClient do
  def upload_data(_dataset_id, _data) do
    Process.sleep(250)
    :ok
  end
end
