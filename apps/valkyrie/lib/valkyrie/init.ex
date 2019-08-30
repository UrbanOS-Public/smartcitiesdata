defmodule Valkyrie.Init do
  @moduledoc false

  use Task, restart: :transient

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    Brook.get_all_values!(:datasets)
    |> Enum.each(&Valkyrie.DatasetProcessor.start/1)
  end
end
