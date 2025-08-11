defmodule Reaper.ElsaBehaviour do
  @callback produce(any(), any(), any(), any()) :: :ok | {:error, any()}
  @callback create_topic(any(), any()) :: :ok | {:error, any()}
  @callback start_link(any()) :: {:ok, pid()} | {:error, any()}
  @callback topic?(any(), any()) :: boolean()
  @callback ready?(any()) :: any()
end