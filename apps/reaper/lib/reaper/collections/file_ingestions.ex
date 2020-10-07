defmodule Reaper.Collections.FileIngestions do
  @moduledoc false

  @instance_name Reaper.instance_name()

  use Reaper.Collections.BaseDataset, instance: @instance_name, collection: :file_ingestions
end
