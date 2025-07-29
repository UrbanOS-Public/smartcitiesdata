defmodule ElsaMock do
  @moduledoc false
  # Mox mock for Elsa service
  
  @callback delete_topic(any(), any()) :: :ok | {:error, any()}
end