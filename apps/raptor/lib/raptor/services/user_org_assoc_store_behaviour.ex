defmodule Raptor.Services.UserOrgAssocStoreBehaviour do
  @callback get_all() :: list(map())
  @callback get_all_by_user(String.t()) :: list(map())
  @callback get(String.t(), String.t()) :: map()
  @callback persist(Raptor.Schemas.UserOrgAssoc.t()) :: any()
  @callback delete(Raptor.Schemas.UserOrgAssoc.t()) :: any()
end
