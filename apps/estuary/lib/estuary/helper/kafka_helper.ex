defmodule Estuary.KafkaHelper do
  def list_exisiting_topics do
    Elsa.list_topics(localhost: 9092)
  end
end
