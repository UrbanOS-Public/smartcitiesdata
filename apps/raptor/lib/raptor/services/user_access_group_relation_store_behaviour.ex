defmodule Raptor.Services.UserAccessGroupRelationStoreBehaviour do
  @callback get_all() :: list(map())
  @callback get_all_by_user(String.t()) :: list(map())
  @callback get(String.t(), String.t()) :: map()
  @callback persist(Raptor.Schemas.UserAccessGroupRelation.t()) :: any()
  @callback delete(Raptor.Schemas.UserAccessGroupRelation.t()) :: any()
end
