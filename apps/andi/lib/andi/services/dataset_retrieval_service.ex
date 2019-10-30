defmodule Andi.Services.DatasetRetrieval do
  import Andi, only: [instance_name: 0]

  def get_all(instance \\ instance_name()) do
    Brook.get_all_values(instance, :dataset)
  end
end
