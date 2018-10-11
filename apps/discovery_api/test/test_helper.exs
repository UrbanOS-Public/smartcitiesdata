ExUnit.start()

defmodule MockHelper do
  defmacro called_times(times, {{:., _, [module, f]}, _, args}) do
    quote do
      unquote(times) == :meck.num_calls(unquote(module), unquote(f), unquote(args))
    end
  end
end
