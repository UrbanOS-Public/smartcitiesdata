defmodule Estuary.KafkaHelper do
  def list_exisiting_topics do
    Elsa.list(localhost: 9092)
  end
end
