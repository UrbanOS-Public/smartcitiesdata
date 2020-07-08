defmodule AndiWeb.EditLiveView.FinalizeFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.ConnCase
  import Phoenix.LiveViewTest

  use Placebo
  import Checkov

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.FormTools
  alias Andi.InputSchemas.CronTools
  alias Andi.InputSchemas.Datasets

  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_values: 2,
      get_attributes: 3,
      find_elements: 2
    ]

  import Andi.Test.CronTestHelpers,
    only: [
      future_year: 0
    ]

  @url_path "/datasets/"

  describe "one-time ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "once"
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Immediate ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#finalize_form_data_cadence_type_once", "checked"))
    end

    test "shows only hidden inputs for the sub-forms", %{html: html} do
      assert Enum.empty?(find_elements(html, ~s(.finalize-form__scheduler--visible input[type]:not([type="hidden"])))
    end
  end

  describe "never ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "never"
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Never ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#finalize_form_data_cadence_type_never", "checked"))
    end

    test "shows only hidden input for the sub-forms", %{html: html} do
      assert Enum.empty?(find_elements(html, ~s(.finalize-form__scheduler--visible input[type]:not([type="hidden"])))
    end
  end

  describe "repeat ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "0 * * * * *"
          }
        })

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the repeat ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#finalize_form_data_cadence_type_repeating", "checked"))
    end

    test "shows cron scheduler", %{html: html} do
      refute Enum.empty?(find_elements(html, ~s(.finalize-form__scheduler--visible input[id*="finalize_form_data_repeating_schedule"]:not([type="hidden"])))

      assert "0 * * * * *" == get_crontab_from_html(html)
    end

    data_test "does not allow schedules more frequent than every 10 seconds for #{second_interval}", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "*/#{second_interval} * * * * *"
          }
        })

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      finalize_form_data = %{
        "cadence_type" => "repeating",
        "repeating_schedule" => %{
          "second" => "*/#{second_interval}",
          "minute" => "*",
          "hour" => "*",
          "day" => "*",
          "month" => "*",
          "week" => "*"
        }
      }
      render_change(view, :save, %{"form_data" => form_data, "finalize_form_data" => finalize_form_data})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where(second_interval: ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
    end

    data_test "marks \"#{cronstring}\" as invalid", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{cadence: cronstring}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      finalize_form_data = %{
        "cadence_type" => "repeating",
        "repeating_schedule" => CronTools.cronstring_to_cronlist!(cronstring)
      }

      render_change(view, :save, %{"form_data" => form_data, "finalize_form_data" => finalize_form_data})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where([
        [:cronstring],
        [""],
        ["1 2 3 4"],
        ["1 nil 2 3 4 5"]
      ])
    end
  end

  describe "future ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "0 1 17 15 11 * 2010"
          }
        })

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html,
        dataset: dataset
      ]
    end

    test "shows the future ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#finalize_form_data_cadence_type_future", "checked"))
    end

    test "shows future scheduler", %{html: html} do
      refute Enum.empty?(find_elements(html, ~s(.finalize-form__scheduler--visible input[id*="finalize_form_data_future_schedule"]:not([type="hidden"])))

      assert ["2010-11-15"] == get_values(html, "#finalize_form_data_future_schedule_date")
      assert ["12:01:00"] == get_values(html, "#finalize_form_data_future_schedule_time")
    end

    data_test "validates and sets cronstring based on date and time", %{dataset: dataset, view: view} do
      form_data = FormTools.form_data_from_andi_dataset(dataset)
      finalize_form_data = %{
        "cadence_type" => "future",
        "future_schedule" => %{
          "date" => date,
          "time" => time
        }
      }

      html = render_change(view, "validate", %{"form_data" => form_data, "finalize_form_data" => finalize_form_data})

      assert [cronstring] == get_values(html, "#form_data_technical_cadence")

      where([
        [:date, :time, :cronstring],
        ["2010-01-01", "00:00:00", ""],
        ["#{future_year()}-01-01", "00:00:00", "0 0 5 1 1 * #{future_year()}"],
        ["", "00:00:00", ""],
        ["#{future_year()}-01-01", "", ""],
        ["#{future_year()}-02-03", "07:01", "0 1 12 3 2 * #{future_year()}"],
      ])
    end
  end

  describe "quick schedule/cron" do
    setup do
      dataset = TDG.create_dataset(%{technical: %{cadence: "1 1 1 * * *"}})

      {:ok, andi_dataset} = Datasets.update(dataset)
      [dataset: andi_dataset]
    end

    data_test "quick schedule #{schedule}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      finalize_form_data = %{
        "cadence_type" => "repeating",
        "quick_cron" => schedule
      }
      render_change(view, "save", %{"form_data" => form_data, "finalize_form_data" => finalize_form_data})
      html = render(view)

      assert expected_crontab == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where([
        [:schedule, :expected_crontab],
        ["hourly", "0 0 * * * *"],
        ["daily", "0 0 0 * * *"],
        ["weekly", "0 0 0 * * 0"],
        ["monthly", "0 0 0 1 * *"],
        ["yearly", "0 0 0 1 1 *"]
      ])
    end

    test "set schedule manually", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      finalize_form_data = %{
        "cadence_type" => "repeating",
        "quick_cron" => "",
        "repeating_schedule" => CronTools.cronstring_to_cronlist!(dataset.technical.cadence)
      }
      render_change(view, "save", %{"form_data" => form_data, "finalize_form_data" => finalize_form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles five-character cronstrings", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "4 2 7 * *"}})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(andi_dataset)
      finalize_form_data = %{
        "cadence_type" => "repeating",
        "repeating_schedule" => CronTools.cronstring_to_cronlist!(dataset.technical.cadence)
      }
      render_change(view, "save", %{"form_data" => form_data, "finalize_form_data" => finalize_form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles cadence of never", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "never"}})
      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end
  end

  defp get_crontab_from_html(html) do
    html
    |> get_values(".finalize-form__schedule-input-field input")
    |> Enum.join(" ")
    |> String.trim_leading()
  end
end
