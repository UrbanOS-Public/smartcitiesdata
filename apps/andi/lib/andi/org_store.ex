defmodule Andi.OrgStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for andi org.
  """

  import Andi

  @collection :org

  def get(id) do
    Brook.get(instance_name(), @collection, id)
  end

  def get_all() do
    Brook.get_all_values(instance_name(), @collection)
  end
end
