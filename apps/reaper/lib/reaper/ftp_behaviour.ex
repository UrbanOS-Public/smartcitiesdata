defmodule Reaper.FtpBehaviour do
  @callback open(charlist()) :: {:ok, pid()} | {:error, atom()}
  @callback user(pid(), charlist(), charlist()) :: :ok | {:error, atom()}
  @callback recv(pid(), charlist(), String.t()) :: :ok | {:error, atom()}
end