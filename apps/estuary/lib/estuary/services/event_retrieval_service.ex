defmodule Estuary.Services.EventRetrievalService do
  @moduledoc """
  Interface for retrieving events.
  """
  import Estuary, only: [instance_name: 0]
  alias Estuary.Query.Select

  def get_all() do
    case Select.select_table() do
      {:ok, events} -> events
      {:error, reason} -> raise reason
    end
  end

  #   def get_all(instance \\ instance_name()) do
  #     Brook.get_all_values(instance, :dataset)
  #   end

  #   def get_all!(instance \\ instance_name()) do
  # case get_all(instance) do
  #   {:ok, events} -> events
  #   {:error, reason} -> raise reason
  # end
  #   end  
end
