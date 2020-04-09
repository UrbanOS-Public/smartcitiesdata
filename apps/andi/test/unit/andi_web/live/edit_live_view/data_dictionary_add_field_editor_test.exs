defmodule AndiWeb.EditLiveView.DataDictionaryAddFieldEditorTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Checkov

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_value: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_attributes: 3
    ]

  @url_path "/datasets/"
