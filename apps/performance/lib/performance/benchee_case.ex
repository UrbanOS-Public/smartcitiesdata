defmodule Performance.BencheeCase do
  @moduledoc """
  An ExUnit case that will set up a benchee run for you, in a more readable way
  """

  use ExUnit.CaseTemplate
  require Logger

  using opts do
    log_level = Keyword.get(opts, :log_level, :warn)

    quote do
      use Divo
      require Logger

      alias Performance.Cve
      alias Performance.Kafka
      alias Performance.SetupConfig

      @moduletag :performance
      @moduletag log_level: unquote(log_level)
    end
  end

  setup_all do
    Agent.start(fn -> 0 end, name: :counter)

    [
      benchee_run: &benchee_run/1
    ]
  end

  setup tags do
    Logger.configure(level: tags[:log_level])
  end

  defp benchee_run(opts) do
    {jobs, hooks} = Keyword.split(opts, [:under_test])
    wrapped_hooks = wrap_hooks(hooks)

    Benchee.run(
      %{"under_test" => jobs[:under_test]},
      wrapped_hooks
    )
  end

  defp wrap_hooks(hooks) do
    Keyword.update(hooks, :before_scenario, &reset_iteration/1, &wrap_in_reset_iteration/1)
    |> Keyword.update(:before_each, &log_iteration/1, &wrap_in_log_iteration/1)
    |> Keyword.update(:after_each, &log_input_and_output/1, &wrap_in_log_input_and_output/1)
    |> Keyword.update(:after_scenario, &log_input_and_output/1, &wrap_in_log_input_and_output/1)
  end

  defp wrap_in_log_input_and_output(hook) do
    fn thing ->
      thing
      |> log_inputs()
      |> hook.()
      |> log_outputs()
    end
  end

  defp log_input_and_output(thing) do
    thing
    |> log_inputs()
    |> log_outputs()
  end

  defp log_inputs(thing) do
    Logger.debug("Hook inputs #{inspect(thing)}")
    thing
  end

  defp log_outputs(thing) do
    Logger.debug("Hook outputs #{inspect(thing)}")
    thing
  end

  defp wrap_in_reset_iteration(hook) do
    fn thing ->
      thing
      |> reset_iteration()
      |> log_inputs()
      |> hook.()
      |> log_outputs()
    end
  end

  defp wrap_in_log_iteration(hook) do
    fn thing ->
      thing
      |> log_iteration()
      |> log_inputs()
      |> hook.()
      |> log_outputs()
    end
  end

  defp reset_iteration(thing) do
    Agent.update(:counter, fn _s -> 0 end)
    thing
  end

  defp log_iteration(thing) do
    iteration = Agent.get_and_update(:counter, fn s -> {s, s + 1} end)
    Logger.info("Iteration #{inspect(iteration)}")
    thing
  end

end
