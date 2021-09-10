defmodule Raptor.Services.OrgStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for a raptor org.
  """

  @instance_name Raptor.instance_name()

  @collection :org

  def get(id) do
    Brook.get(@instance_name, @collection, id)
  end

  def get_all() do
    Brook.get_all_values(@instance_name, @collection)
  end

  def update(%SmartCity.Organization{} = org) do
    Brook.ViewState.merge(@collection, org.id, org)
  end

  def delete(id) do
    Brook.ViewState.delete(@collection, id)
  end
end
