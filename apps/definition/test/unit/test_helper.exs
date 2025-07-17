ExUnit.start()

Mox.defmock(IdGeneratorMock, for: IdGenerator)
Application.put_env(:definition, :id_generator, IdGeneratorMock)