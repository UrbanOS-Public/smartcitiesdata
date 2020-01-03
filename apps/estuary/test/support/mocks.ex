Mox.defmock(MockReader, for: Pipeline.Reader)
Mox.stub_with(MockReader, Estuary.DataReader)
Mox.defmock(MockTable, for: Pipeline.Writer)
Mox.stub_with(MockTable, Estuary.DataWriter)
