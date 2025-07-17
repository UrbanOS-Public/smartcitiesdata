defmodule Elsa.Behaviour do
  @callback topic?(list(), String.t()) :: boolean()
  @callback create_topic(list(), String.t()) :: :ok | {:error, term()}
  @callback produce(atom(), String.t(), list()) :: :ok | {:error, term()}
end

defmodule Elsa.Supervisor.Behaviour do
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
end