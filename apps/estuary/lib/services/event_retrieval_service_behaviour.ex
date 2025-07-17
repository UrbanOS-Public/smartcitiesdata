defmodule Estuary.Services.EventRetrievalServiceBehaviour do
  @callback get_all() :: {:ok, [map()]} | {:error, any()}
end
