defmodule Forklift.Util do
  @moduledoc """
  Utilities used inside forklift
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

  def chunk_by_byte_size(collection, chunk_byte_size, function \\ &byte_size/1) do
    collection
    |> Enum.chunk_while({0, []}, &chunk(&1, &2, chunk_byte_size, function), &after_chunk/1)
  end

  defp chunk(item, {current_size, current_batch}, chunk_byte_size, function) do
    item_size = function.(item)
    new_total = current_size + item_size

    case new_total < chunk_byte_size do
      true -> add_item_to_batch(new_total, item, current_batch)
      false -> finish_batch(item_size, item, current_batch)
    end
  end

  defp add_item_to_batch(total, item, batch) do
    {:cont, {total, [item | batch]}}
  end

  defp finish_batch(total, item, batch) do
    {:cont, Enum.reverse(batch), {total, [item]}}
  end

  defp after_chunk({_size, []}) do
    {:cont, {0, []}}
  end

  defp after_chunk({_size, current_batch}) do
    finish_batch(0, nil, current_batch)
  end
end
