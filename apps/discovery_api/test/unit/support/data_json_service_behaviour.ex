defmodule DataJsonServiceBehaviour do
  @moduledoc """
  Behaviour for the DataJsonService module to enable mocking
  """
  
  @callback delete_data_json() :: any()
  @callback ensure_data_json_file() :: {:local, binary()} | {:error, any()}
end