defmodule Andi.Services.DatasetRetrieval do
  @moduledoc """
  Interface for retrieving datasets.
  """
  import Andi, only: [instance_name: 0]

  def get_all(instance \\ instance_name()) do
    Brook.get_all_values(instance, :dataset)
  end

  def get_all!(instance \\ instance_name()) do
    case get_all(instance) do
      {:ok, datasets} -> datasets
      {:error, reason} -> raise reason
    end
  end
end
