defmodule Raptor.Services.DatasetStoreBehaviour do
  @callback get_all() :: list(map())
  @callback get(String.t()) :: map()
  @callback persist(Raptor.Schemas.Dataset.t()) :: any()
end
