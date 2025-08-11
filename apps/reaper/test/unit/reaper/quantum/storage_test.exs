defmodule Reaper.Quantum.StorageTest do
  use ExUnit.Case, async: false

  alias Quantum.Job
  alias Reaper.Quantum.Storage
  import Crontab.CronExpression

  @conn :reaper_quantum_storage_redix

  setup do
    # Ensure Redix is not already mocked
    try do
      :meck.unload(Redix)
    rescue
      ErlangError -> :ok
    end
    
    :meck.new(Redix, [:non_strict])
    
    on_exit(fn -> 
      try do
        :meck.unload(Redix)
      rescue
        ErlangError -> :ok
      end
    end)
    
    :ok
  end

  describe "add_job/2" do
    test "persists job into redis" do
      :meck.expect(Redix, :command, fn @conn, ["SET", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1", _] -> {:ok, "OK"} end)
      job = job(name: :ingestion_1)

      assert :ok == Storage.add_job(Reaper.Scheduler, job)

      assert :meck.called(Redix, :command, [@conn, [
                      "SET",
                      "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1",
                      :erlang.term_to_binary(job)
                    ]])
    end
  end

  describe "delete_job/2" do
    test "removes the job from redis" do
      :meck.expect(Redix, :command, fn @conn, ["DEL", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_2"] -> {:ok, 1} end)
      job = job(name: :ingestion_2)

      assert :ok == Storage.delete_job(Reaper.Scheduler, job.name)
      assert :meck.called(Redix, :command, [@conn, ["DEL", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_2"]])
    end
  end

  describe "jobs/1" do
    test "returns all jobs currently persisted" do
      jobs = [
        job(name: :ingestion_1),
        job(name: :ingestion_2),
        job(name: :ingestion_3)
      ]

      binary_jobs = Enum.map(jobs, &:erlang.term_to_binary/1)

      :meck.expect(Redix, :command, fn 
        @conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:job:*"] -> {:ok, ["key1", "key2", "key3"]}
        @conn, ["MGET", "key1", "key2", "key3"] -> {:ok, binary_jobs}
      end)

      assert jobs == Storage.jobs(Reaper.Scheduler)
      assert :meck.called(Redix, :command, [@conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:job:*"]])
      assert :meck.called(Redix, :command, [@conn, ["MGET", "key1", "key2", "key3"]])
    end

    test "returns not_applicable when no jobs found" do
      :meck.expect(Redix, :command, fn @conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:job:*"] -> {:ok, []} end)

      assert :not_applicable == Storage.jobs(Reaper.Scheduler)
      assert false == :meck.called(Redix, :command, [@conn, ["MGET" | :_]])
    end
  end

  describe "update_last_execution_date/2" do
    test "save the last execution date to redis" do
      date = NaiveDateTime.utc_now()
      :meck.expect(Redix, :command, fn @conn, ["SET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date", _] -> {:ok, "OK"} end)

      assert :ok == Storage.update_last_execution_date(Reaper.Scheduler, date)

      assert :meck.called(Redix, :command, [@conn, [
                      "SET",
                      "reaper:quantum:elixir.reaper.scheduler:last_execution_date",
                      :erlang.term_to_binary(date)
                    ]])
    end

    test "will retry saving the last execution date in case of timeout" do
      call_count = :counters.new(1, [])
      :meck.expect(Redix, :command, fn @conn, ["SET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date", _] ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)
        case count do
          0 -> {:error, %Redix.ConnectionError{reason: :timeout}}
          1 -> {:error, %Redix.ConnectionError{reason: :timeout}}
          2 -> {:ok, "OK"}
        end
      end)

      assert :ok == Storage.update_last_execution_date(Reaper.Scheduler, NaiveDateTime.utc_now())

      assert 3 == :meck.num_calls(Redix, :command, [@conn, ["SET" | :_]])
    end
  end

  describe "last_execution_date/1" do
    test "returns last execution date from redis" do
      date = NaiveDateTime.utc_now()
      :meck.expect(Redix, :command, fn @conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date"] -> {:ok, :erlang.term_to_binary(date)} end)

      assert date == Storage.last_execution_date(Reaper.Scheduler)
      assert :meck.called(Redix, :command, [@conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date"]])
    end

    test "return unknown when no last execution date is available" do
      :meck.expect(Redix, :command, fn @conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date"] -> {:ok, nil} end)

      assert :unknown == Storage.last_execution_date(Reaper.Scheduler)
      assert :meck.called(Redix, :command, [@conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date"]])
    end
  end

  describe "update_job_state/3" do
    test "updates existing job state" do
      job = job(name: :ingestion_1)
      updated_job = %{job | state: :inactive}
      :meck.expect(Redix, :command, fn 
        @conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1"] -> {:ok, :erlang.term_to_binary(job)}
        @conn, ["SET", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1", _] -> {:ok, "OK"}
      end)

      assert :ok == Storage.update_job_state(Reaper.Scheduler, :ingestion_1, :inactive)

      assert :meck.called(Redix, :command, [@conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1"]])
      assert :meck.called(Redix, :command, [@conn, [
                      "SET",
                      "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1",
                      :erlang.term_to_binary(updated_job)
                    ]])
    end
  end

  describe "purge/1" do
    test "deletes all data for scheduler" do
      :meck.expect(Redix, :command, fn 
        @conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:*"] -> {:ok, ["key1", "key2", "key3"]}
        @conn, ["DEL", "key1", "key2", "key3"] -> {:ok, 1}
      end)

      assert :ok == Storage.purge(Reaper.Scheduler)

      assert :meck.called(Redix, :command, [@conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:*"]])
      assert :meck.called(Redix, :command, [@conn, ["DEL", "key1", "key2", "key3"]])
    end

    test "does not call delete if no keys are available" do
      :meck.expect(Redix, :command, fn @conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:*"] -> {:ok, []} end)

      assert :ok == Storage.purge(Reaper.Scheduler)

      assert false == :meck.called(Redix, :command, [@conn, ["DEL" | :_]])
    end
  end

  defp job(opts) do
    Reaper.Scheduler.new_job()
    |> Job.set_name(Keyword.fetch!(opts, :name))
    |> Job.set_schedule(Keyword.get(opts, :scheduler, ~e[* * * * *]))
    |> Job.set_task(Keyword.get(opts, :task, fn -> IO.puts("hi") end))
  end
end
