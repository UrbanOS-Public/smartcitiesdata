defmodule AndiWeb.ExtractAuthStepFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import Checkov
  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]
  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_attributes: 3,
      get_text: 2,
      get_value: 2,
      get_select: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions

  @url_path "/ingestions/"
  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "auth step form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()
      auth_step = %{context: %{destination: "foo", url: "bar.com", path: ["path"], cacheTtl: 500}, id: UUID.uuid4(), type: "auth", sequence: 0}
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDataset: dataset.id, name: "sample_ingestion", extractSteps: [auth_step]})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [view: view, html: html, auth_step: auth_step]
    end

    test "destination field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_destination = "new_destination"

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_auth_destination") == new_destination
    end

    test "destination field shows an error if blank", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_destination = ""

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "#destination-error-msg") == "Please enter a valid destination."
    end

    test "url field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_url = "https://example.com"

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_auth_url") == new_url
    end

    test "url field shows an error if blank", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_url = ""

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "#url-error-msg") == "Please enter a valid url - including http:// or https://"
    end

    test "path field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_path = "asdf.qwer"

      form_data = %{
        "path" => new_path
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_path") == new_path
    end

    test "path field shows an error if blank", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_path = ""

      form_data = %{
        "path" => new_path
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "#path-error-msg") == "Please enter a valid response location."
    end

    test "cacheTtl field has default", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      assert get_value(html, "##{auth_step.id}_cacheTtl") == "0"
    end

    test "cacheTtl field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_cacheTtl = "50"

      form_data = %{
        "cacheTtl" => new_cacheTtl
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_cacheTtl") == new_cacheTtl
    end
  end
end
