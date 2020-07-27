defmodule Andi.Harvest.Harvester do
  @moduledoc """
  retreives data json and maps it to a smartcity dataset
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.JSON

 def start_harvesting(arg) do
    # Grab the data from the data json url
    IO.inspect(arg, label: "start havesting")
    Process.sleep(10_000)
    IO.inspect(label: "I'm done harvesting")
   :ok
 end

 def get_data_json(url) do
  {:ok, response} = get(url)
  response.body
 end

end
