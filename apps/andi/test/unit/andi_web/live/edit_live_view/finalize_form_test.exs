defmodule AndiWeb.EditLiveView.FinalizeFormTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest

  use Placebo
  import Checkov

  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.FormTools
  alias Andi.InputSchemas.Datasets

  import FlokiHelpers,
    only: [
      get_values: 2,
      get_attributes: 3,
      find_elements: 2
    ]

  @url_path "/datasets/"

  describe "one-time ingestion" do
    setup %{conn: conn} do
      dataset =
        DatasetHelpers.create_dataset(%{
          technical: %{
            cadence: "once"
          }
        })

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Immediate ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_technical_cadence_once", "checked"))
    end

    test "does not show cron scheduler", %{html: html} do
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))
    end
  end

  describe "never ingestion" do
    setup %{conn: conn} do
      dataset =
        DatasetHelpers.create_dataset(%{
          technical: %{
            cadence: "never"
          }
        })

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Never ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_technical_cadence_never", "checked"))
    end

    test "does not show cron scheduler", %{html: html} do
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))
    end
  end

  describe "repeat ingestion" do
    setup %{conn: conn} do
      dataset =
        DatasetHelpers.create_dataset(%{
          technical: %{
            cadence: "0 * * * * *"
          }
        })

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the repeat ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_technical_cadence_0__________", "checked"))
    end

    test "shows cron scheduler", %{html: html} do
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))

      assert "0 * * * * *" == get_crontab_from_html(html)
    end

    data_test "does not allow schedules more frequent than every 10 seconds", %{conn: conn} do
      dataset =
        DatasetHelpers.create_dataset(%{
          technical: %{
            cadence: "*/#{second_interval} * * * * *"
          }
        })

      DatasetHelpers.add_dataset_to_repo(dataset)
      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)

      dataset_from_save =
        dataset
        |> InputConverter.smrt_dataset_to_changeset()
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update_cadence(any(), any()), return: {:ok, dataset_from_save})
      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      render_change(view, :validate, %{"form_data" => form_data})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where(second_interval: ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
    end

    data_test "marks #{cronstring} as invalid", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{cadence: cronstring}})
      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      dataset_from_save =
        dataset
        |> InputConverter.smrt_dataset_to_changeset()
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update_cadence(any(), any()), return: {:ok, dataset_from_save})
      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      render_change(view, :save, %{"form_data" => form_data})
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

  defp get_crontab_from_html(html) do
    html
    |> get_values(".finalize-form-schedule-input__field")
    |> Enum.join(" ")
  end
end
