defmodule ElsaBehaviour do
  @moduledoc false
  # Mox mock behaviour for Elsa service

  @callback create_topic(any(), any()) :: :ok | {:error, any()}
  @callback delete_topic(any(), any()) :: :ok | {:error, any()}
  @callback topic?(any(), any()) :: boolean()
  @callback produce(any(), any(), any(), keyword()) :: :ok | {:error, any()}
end