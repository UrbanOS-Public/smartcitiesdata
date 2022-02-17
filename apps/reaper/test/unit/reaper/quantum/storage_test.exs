defmodule Reaper.Quantum.StorageTest do
  use ExUnit.Case
  use Placebo

  alias Quantum.Job
  alias Reaper.Quantum.Storage
  import Crontab.CronExpression

  @conn :reaper_quantum_storage_redix

  describe "add_job/2" do
    test "persists job into redis" do
      allow Redix.command(any(), any()), return: {:ok, "OK"}
      job = job(name: :ingestion_1)

      assert :ok == Storage.add_job(Reaper.Scheduler, job)

      assert_called Redix.command(@conn, [
                      "SET",
                      "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1",
                      :erlang.term_to_binary(job)
                    ])
    end
  end

  describe "delete_job/2" do
    test "removes the job from redis" do
      allow Redix.command(any(), any()), return: {:ok, 1}
      job = job(name: :ingestion_2)

      assert :ok == Storage.delete_job(Reaper.Scheduler, job.name)
      assert_called Redix.command(@conn, ["DEL", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_2"])
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

      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, ["key1", "key2", "key3"]}
      allow Redix.command(any(), ["MGET" | any()]), return: {:ok, binary_jobs}

      assert jobs == Storage.jobs(Reaper.Scheduler)
      assert_called Redix.command(@conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:job:*"])
      assert_called Redix.command(@conn, ["MGET", "key1", "key2", "key3"])
    end

    test "returns not_applicable when no jobs found" do
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, []}

      assert :not_applicable == Storage.jobs(Reaper.Scheduler)
      refute_called Redix.command(any(), ["MGET" | any()])
    end
  end

  describe "update_last_execution_date/2" do
    test "save the last execution date to redis" do
      allow Redix.command(any(), any()), return: {:ok, "OK"}

      date = NaiveDateTime.utc_now()

      assert :ok == Storage.update_last_execution_date(Reaper.Scheduler, date)

      assert_called Redix.command(@conn, [
                      "SET",
                      "reaper:quantum:elixir.reaper.scheduler:last_execution_date",
                      :erlang.term_to_binary(date)
                    ])
    end

    test "will retry saving the last execution date in case of timeout" do
      return_values = [
        {:error, %Redix.ConnectionError{reason: :timeout}},
        {:error, %Redix.ConnectionError{reason: :timeout}},
        {:ok, "OK"}
      ]

      allow Redix.command(any(), any()), seq: return_values

      assert :ok == Storage.update_last_execution_date(Reaper.Scheduler, NaiveDateTime.utc_now())

      assert_called Redix.command(@conn, ["SET" | any()]), times(3)
    end
  end

  describe "last_execution_date/1" do
    test "returns last execution date from redis" do
      date = NaiveDateTime.utc_now()
      allow Redix.command(any(), any()), return: {:ok, :erlang.term_to_binary(date)}

      assert date == Storage.last_execution_date(Reaper.Scheduler)
      assert_called Redix.command(@conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date"])
    end

    test "return unknown when no last execution date is available" do
      allow Redix.command(any(), any()), return: {:ok, nil}

      assert :unknown == Storage.last_execution_date(Reaper.Scheduler)
      assert_called Redix.command(@conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:last_execution_date"])
    end
  end

  describe "update_job_state/3" do
    test "updates existing job state" do
      job = job(name: :ingestion_1)
      allow Redix.command(any(), ["GET" | any()]), return: {:ok, :erlang.term_to_binary(job)}
      allow Redix.command(any(), ["SET" | any()]), return: {:ok, "OK"}

      assert :ok == Storage.update_job_state(Reaper.Scheduler, :ingestion_1, :inactive)

      updated_job = %{job | state: :inactive}
      assert_called Redix.command(@conn, ["GET", "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1"])

      assert_called Redix.command(@conn, [
                      "SET",
                      "reaper:quantum:elixir.reaper.scheduler:job:ingestion_1",
                      :erlang.term_to_binary(updated_job)
                    ])
    end
  end

  describe "purge/1" do
    test "deletes all data for scheduler" do
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, ["key1", "key2", "key3"]}
      allow Redix.command(any(), ["DEL" | any()]), return: {:ok, 1}

      assert :ok == Storage.purge(Reaper.Scheduler)

      assert_called Redix.command(@conn, ["KEYS", "reaper:quantum:elixir.reaper.scheduler:*"])
      assert_called Redix.command(@conn, ["DEL", "key1", "key2", "key3"])
    end

    test "does not call delete if no keys are available" do
      allow Redix.command(any(), any()), return: {:ok, 4}
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, []}

      assert :ok == Storage.purge(Reaper.Scheduler)

      refute_called Redix.command(@conn, ["DEL" | any()])
    end
  end

  defp job(opts) do
    Reaper.Scheduler.new_job()
    |> Job.set_name(Keyword.fetch!(opts, :name))
    |> Job.set_schedule(Keyword.get(opts, :scheduler, ~e[* * * * *]))
    |> Job.set_task(Keyword.get(opts, :task, fn -> IO.puts("hi") end))
  end
end
