defmodule Forklift.IngestionTimerTest do
  use ExUnit.Case
  use Placebo

  import Mock

  setup do
    [ingestion_id: Faker.UUID.v4(), extract_time: Timex.now() |> Timex.to_unix(), dataset: %{}]
  end

  describe "IngestionTimerTest" do
    test "should not compact if finished", %{ingestion_id: ingestion_id, extract_time: extract_time, dataset: dataset} do
      with_mocks([
        {Forklift.IngestionProgress, [],
         [
           complete_extract: fn _any -> :ingestion_complete end,
           is_extract_done: fn _any -> true end
         ]},
        {Forklift.Jobs.DataMigration, [],
         [compact: fn _dataset, _ingestion_id, _extract_time -> {:ok, "completed"} end]}
      ]) do
        extract_id = get_extract_id(ingestion_id, extract_time)

        Forklift.IngestionTimer.compact_if_not_finished(dataset, ingestion_id, extract_id, extract_time)

        assert_not_called(Forklift.IngestionProgress.complete_extract(extract_id))
        assert_not_called(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_time))
      end
    end

    test "should compact if not finished", %{ingestion_id: ingestion_id, extract_time: extract_time, dataset: dataset} do
      with_mocks([
        {Forklift.IngestionProgress, [],
         [
           complete_extract: fn _any -> :ingestion_complete end,
           is_extract_done: fn _any -> false end
         ]},
        {Forklift.Jobs.DataMigration, [],
         [compact: fn _dataset, _ingestion_id, _extract_time -> {:ok, "completed"} end]}
      ]) do
        extract_id = get_extract_id(ingestion_id, extract_time)

        Forklift.IngestionTimer.compact_if_not_finished(dataset, ingestion_id, extract_id, extract_time)

        Mock.assert_called(Forklift.IngestionProgress.complete_extract(extract_id))
        Mock.assert_called(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_time))
      end
    end
  end

  defp get_extract_id(ingestion_id, extract_time) do
    ingestion_id <> "_" <> (extract_time |> Integer.to_string())
  end
end
