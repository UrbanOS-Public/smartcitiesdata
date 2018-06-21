defmodule CotaStreamingConsumer.Application do
  use Application

  require Cachex.Spec

  @cache Application.get_env(:cota_streaming_consumer, :cache)

  def start(_type, _args) do
    import Supervisor.Spec

    set_kaffe_endpoints(System.get_env("KAFKA_BROKERS"))
    set_kaffe_topics(System.get_env("COTA_DATA_TOPIC"))

    children = [
      cachex(),
      supervisor(CotaStreamingConsumerWeb.Endpoint, [])
      | Application.get_env(:cota_streaming_consumer, :children, [])
    ]

    opts = [strategy: :one_for_one, name: CotaStreamingConsumer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    CotaStreamingConsumerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp cachex do
    %{
      id: Cachex,
      start: {Cachex, :start_link, [@cache]}
    }
  end

  defp set_kaffe_endpoints(nil), do: false

  defp set_kaffe_endpoints(kafka_brokers) do
    endpoints =
      kafka_brokers
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn entry -> String.split(entry, ":") end)
      |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

    config =
      Application.get_env(:kaffe, :consumer)
      |> Keyword.put(:endpoints, endpoints)

    Application.put_env(:kaffe, :consumer, config, persistent: true)
  end

  defp set_kaffe_topics(nil), do: false

  defp set_kaffe_topics(topic) do
    config =
      Application.get_env(:kaffe, :consumer)
      |> Keyword.put(:topics, [topic])

    Application.put_env(:kaffe, :consumer, config, persistent: true)
  end
end
