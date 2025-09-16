defmodule Forklift.Test.DatasetsBehaviour do
  @callback update(any) :: any
  @callback get!(any) :: any
  @callback get_all!() :: any
  @callback get_events!(any) :: any
  @callback delete(any) :: any
end

defmodule Forklift.Test.BrookBehaviour do
  @callback get_all_values!(atom, atom) :: [any]
  @callback get!(atom, atom, any) :: any
end

defmodule Forklift.Test.BrookSendBehaviour do
  @callback send(any, any, any, any) :: :ok
end


defmodule Forklift.Test.DataWriterBehaviour do
  @callback init(any) :: :ok
end

defmodule Forklift.Test.PrestigeHelperBehaviour do
  @callback table_exists?(any) :: boolean
  @callback execute_query(any) :: {:ok, any} | {:error, any}
  @callback count(any) :: {:ok, any} | {:error, any}
  @callback count_query(String.t()) :: {:ok, integer()} | {:error, term()}
end

defmodule Forklift.Test.TelemetryEventBehaviour do
  @callback add_event_metrics(any, any) :: :ok
end

defmodule Forklift.Test.PrestigeBehaviour do
  @callback new_session(any) :: any
  @callback execute(any, any) :: any
  @callback query!(any, any) :: any
end
