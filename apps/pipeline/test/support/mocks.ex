defmodule Elsa.Behaviour do
  @callback topic?(any, any) :: boolean()
  @callback create_topic(any, any) :: any()
end

defmodule Pipeline.Writer.TableWriter.Compaction.Behaviour do
  @callback measure(any, any) :: any
end

defmodule Pipeline.Writer.S3Writer.Compaction.Behaviour do
  @callback measure(any, any) :: any
end

defmodule Prestige.Behaviour do
  @callback new_session(any) :: any
  @callback execute(any, any) :: any
end

defmodule Pipeline.Test.Mocks do
  @moduledoc """
  Mocks for testing Pipeline components
  """

  # Define mocks for external dependencies
  Mox.defmock(TopicReaderMock, for: Pipeline.Reader.TopicReader.Behaviour)
  Mox.defmock(ElsaMock, for: Elsa.Behaviour)
  Mox.defmock(CompactionMock, for: Pipeline.Writer.TableWriter.Compaction.Behaviour)
  Mox.defmock(S3CompactionMock, for: Pipeline.Writer.S3Writer.Compaction.Behaviour)
  Mox.defmock(PrestigeMock, for: Prestige.Behaviour)
end
