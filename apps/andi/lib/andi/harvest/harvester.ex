defmodule Andi.Harvest.Harvester do
 def start_harvesting(arg) do
    # Grab the data from the data json url




    IO.inspect(arg, label: "start havesting")
    Process.sleep(10_000)
    IO.inspect(label: "I'm done harvesting")
   :ok
 end
end
