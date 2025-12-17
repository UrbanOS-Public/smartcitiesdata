defmodule Forklift.Test.DatasetsBehaviour do
  @moduledoc """
  Test behaviour for mocking dataset operations.
  """
  @callback update(any) :: any
  @callback get!(any) :: any
  @callback get_all!() :: any
  @callback get_events!(any) :: any
  @callback delete(any) :: any
end

defmodule Forklift.Test.BrookBehaviour do
  @moduledoc """
  Test behaviour for mocking Brook state management operations.
  """
  @callback get_all_values!(atom, atom) :: [any]
  @callback get!(atom, atom, any) :: any
end

defmodule Forklift.Test.BrookSendBehaviour do
  @moduledoc """
  Test behaviour for mocking Brook event sending.
  """
  @callback send(any, any, any, any) :: :ok
end

defmodule Forklift.Test.DataWriterBehaviour do
  @moduledoc """
  Test behaviour for mocking data writer initialization.
  """
  @callback init(any) :: :ok
end

defmodule Forklift.Test.PrestigeHelperBehaviour do
  @moduledoc """
  Test behaviour for mocking Prestige database helper operations.
  """
  @callback table_exists?(any) :: boolean
  @callback execute_query(any) :: {:ok, any} | {:error, any}
  @callback count(any) :: {:ok, any} | {:error, any}
  @callback count_query(String.t()) :: {:ok, integer()} | {:error, term()}
end

defmodule Forklift.Test.TelemetryEventBehaviour do
  @moduledoc """
  Test behaviour for mocking telemetry event operations.
  """
  @callback add_event_metrics(any, any) :: :ok
end

defmodule Forklift.Test.PrestigeBehaviour do
  @moduledoc """
  Test behaviour for mocking Prestige database session operations.
  """
  @callback new_session(any) :: any
  @callback execute(any, any) :: any
  @callback query!(any, any) :: any
end

defmodule Forklift.Test.DataMigrationBehaviour do
  @moduledoc """
  Test behaviour for mocking data migration operations.
  """
  @callback compact(any, any, any) :: {:ok, any} | {:error, any}
end
