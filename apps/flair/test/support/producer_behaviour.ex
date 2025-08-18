defmodule Flair.ProducerBehaviour do
  @moduledoc """
  Behaviour for mocking Flair.Producer in tests
  """
  
  @callback add_messages(atom(), list()) :: :ok | {:error, term()}
end