defmodule Valkyrie.TopicHelper do
  @moduledoc false

  require Logger

  def get_endpoints() do
    Application.get_env(:valkyrie, :endpoints)
  end

  def delete_topics(dataset_id) do
    input_topic_name(dataset_id)
    |> delete_topic()

    output_topic_name(dataset_id)
    |> delete_topic()
  end

  defp delete_topic(topic) do
    Logger.debug("#{__MODULE__}: Deleting Topic: #{topic}")

    case Elsa.delete_topic(get_endpoints(), topic) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted topic: #{topic}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete topic: #{topic}, Reason: #{inspect(error)}")
    end
  end

  def input_topic_name(dataset_id), do: "#{input_topic_prefix()}#{dataset_id}"

  defp input_topic_prefix() do
    Application.get_env(:valkyrie, :input_topic_prefix, "raw-")
  end

  def output_topic_name(dataset_id), do: "#{output_topic_prefix()}#{dataset_id}"

  defp output_topic_prefix() do
    Application.get_env(:valkyrie, :output_topic_prefix, "transformed-")
  end
end
