defmodule Reaper.DataSlurperS3Behaviour do
  @callback slurp(String.t(), String.t(), map(), any(), any(), any()) :: {:file, String.t()} | {:error, any()}
end