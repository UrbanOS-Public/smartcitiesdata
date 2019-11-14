defmodule Reaper do
  @moduledoc false

  def currently_running_jobs() do
    Reaper.Horde.Registry.get_all()
  end

	def redis_args() do
		Enum.filter(Application.get_env(:redix, :args, []), fn
  		{_, nil} -> false
  		{_, ""} -> false
  		_ -> true
		end)
	end

	def redis_quantum_storage() do
		Enum.filter(Application.get_env(:reaper, Reaper.Quantum.Storage, []), fn
  		{_, nil} -> false
  		{_, ""} -> false
  		_ -> true
		end)
	end
end
