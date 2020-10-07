defmodule Valkyrie.Init do
  @moduledoc false
  use Application.Initializer

  @instance_name Valkyrie.instance_name()

  def do_init(_opts) do
    Brook.get_all_values!(@instance_name, :datasets)
    |> Enum.each(&Valkyrie.DatasetProcessor.start/1)
  end
end
