defmodule ObjectStorageServiceBehaviour do
  @moduledoc """
  Behaviour for ObjectStorageService module to enable mocking
  """
  
  @callback download_file_as_stream(any(), any()) :: {:ok, any(), binary()} | {:error, any()}
end