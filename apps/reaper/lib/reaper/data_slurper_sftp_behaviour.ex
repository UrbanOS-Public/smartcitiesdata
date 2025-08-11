defmodule Reaper.DataSlurperSftpBehaviour do
  @callback slurp(String.t(), String.t(), any(), any(), any(), any()) :: {:file, String.t()} | {:error, any()}
end