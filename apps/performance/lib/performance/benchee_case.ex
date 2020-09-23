defmodule Performance.BencheeCase do
  @moduledoc """
  An ExUnit case that will set up a benchee run for you, in a more readable way
  """

  use ExUnit.CaseTemplate
  require Logger

  using opts do
    otp_app = Keyword.fetch!(opts, :otp_app)
    endpoints = Keyword.get(opts, :endpoints, [])
    topic_prefixes = Keyword.get(opts, :topic_prefixes, [])
    topics = Keyword.get(opts, :topics, [])
    log_level = Keyword.get(opts, :log_level, :warn)
    override_defaults = Keyword.get(opts, :override_defaults, false)

    quote do
      use Divo
      require Logger

      alias Performance.Cve
      alias Performance.Kafka
      alias Performance.SetupConfig

      @moduletag :performance
      @moduletag log_level: unquote(log_level)

      @otp_app unquote(otp_app)
      @endpoints unquote(endpoints)
      @topic_prefixes unquote(topic_prefixes)
      @topics unquote(topics)

      def benchee_run(opts) do
        {jobs, rest} = Keyword.split(opts, [:under_test])
        defaults = [
          before_scenario: [&reset_iteration/1],
          before_each: [&log_iteration/1],
          after_each: [],
          after_scenario: []
        ]
        {hooks, options} = Keyword.split(rest, Keyword.keys(defaults))
        wrapped_hooks = Performance.BencheeCase.__merge_hooks__(hooks, defaults, unquote(override_defaults))

        Benchee.run(
          %{"under_test" => jobs[:under_test]},
          wrapped_hooks ++ options
        )
      end

      defp tune_consumer_parameters(params) do
        Kafka.tune_consumer_parameters(@otp_app, params)
      end

      defp reset_iteration(inputs) do
        Agent.update(:counter, fn _s -> 1 end)
        inputs
      end

      defp log_iteration(inputs) do
        iteration = Agent.get_and_update(:counter, fn s -> {s, s + 1} end)
        Logger.info("Iteration #{inspect(iteration)}")
        inputs
      end

      defp create_kafka_topics(dataset) do
        from_prefixes = Kafka.setup_topics(@topic_prefixes, dataset, @endpoints)
        from_names = Kafka.setup_topics(@topics, @endpoints)

        combined = Tuple.to_list(from_prefixes) ++ Tuple.to_list(from_names)
        List.to_tuple(combined)
      end

      defp load_messages(dataset, topic, messages, chunk_size \\ 10_000) do
        Kafka.load_messages(@endpoints, dataset, topic, messages, length(messages), 10_000)
      end

      defp get_message_count(topic, num_partitions \\ 1) do
        Kafka.get_message_count(@endpoints, topic, num_partitions)
      end

      defp delete_kafka_topics(dataset) do
        Kafka.delete_topics(@topic_prefixes, dataset, @endpoints)
        Kafka.delete_topics(@topics, @endpoints)
      end
    end
  end

  setup_all do
    Agent.start(fn -> 1 end, name: :counter)

    :ok
  end

  setup tags do
    Logger.configure(level: tags[:log_level])
  end

  def __merge_hooks__(hooks, defaults, override \\ false) do
    Keyword.merge(defaults, hooks, fn _key, def_v, hook_v ->
      wrapped_hook_v = List.wrap(hook_v)

      case override do
        false -> def_v ++ wrapped_hook_v
        true -> wrapped_hook_v
      end
    end)
    |> Enum.map(fn {k, v} ->
      hook = fn inputs ->
        Enum.reduce(v, inputs, fn i, a ->
          i.(a)
        end)
      end
      {k, hook}
    end)
    |> Keyword.new()
  end
end
