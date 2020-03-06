defmodule Andi.DatasetUtil do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for andi datasets.
  """

  import Andi

  @collection :dataset

  def delete(id) do
    Brook.ViewState.delete(@collection, id)
  end
end
