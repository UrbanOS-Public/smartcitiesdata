defmodule Valkyrie.Init do
  @moduledoc false
  use Application.Initializer

  def do_init(_opts) do
    Brook.get_all_values!(:datasets)
    |> Enum.each(&Valkyrie.DatasetProcessor.start/1)
  end
end
