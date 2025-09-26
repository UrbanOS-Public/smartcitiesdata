defmodule Raptor.Services.DatasetAccessGroupRelationStoreBehaviour do
  @callback get_all() :: list(map())
  @callback get_all_by_dataset(String.t()) :: list(map())
  @callback get(String.t(), String.t()) :: map()
  @callback persist(Raptor.Schemas.DatasetAccessGroupRelation.t()) :: any()
  @callback delete(Raptor.Schemas.DatasetAccessGroupRelation.t()) :: any()
end
