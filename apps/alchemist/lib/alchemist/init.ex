defmodule Alchemist.Init do
  @moduledoc false
  use Application.Initializer

  @instance_name Alchemist.instance_name()

  def do_init(_opts) do
    Brook.get_all_values!(@instance_name, :ingestions)
    |> Enum.each(&Alchemist.IngestionProcessor.start/1)
  end
end
