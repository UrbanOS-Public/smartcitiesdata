defmodule Reaper.TopicManagerBehaviour do
  @callback delete_topic(String.t()) :: :ok | :error
end