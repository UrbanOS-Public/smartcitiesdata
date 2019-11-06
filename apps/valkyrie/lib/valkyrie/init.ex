defmodule Valkyrie.Init do
  @moduledoc false
  use Application.Initializer

  @instance Valkyrie.Application.instance()

  def do_init(_opts) do
    Brook.get_all_values!(@instance, :datasets)
    |> Enum.each(&Valkyrie.DatasetProcessor.start/1)
  end
end
