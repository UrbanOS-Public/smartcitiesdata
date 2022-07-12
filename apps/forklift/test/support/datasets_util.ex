alias Forklift.Datasets

defmodule Forklift.TestSupport.Datasets do
  def delete_all() do
    Datasets.get_all!()
    |> Enum.map(fn %{id: id} -> id end)
    |> Enum.each(&Datasets.delete/1)
  end
end
