defmodule Estuary.Util do
  @moduledoc """
  Utilities used inside estuary
  """

  def add_to_metadata(datum, field, value) do
    Map.update!(datum, :_metadata, fn metadata ->
      Map.put(metadata, field, value)
    end)
  end

  def remove_from_metadata(datum, field) do
    Map.update!(datum, :_metadata, fn metadata ->
      Map.delete(metadata, field)
    end)
  end
end
