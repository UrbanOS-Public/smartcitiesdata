import Mox

defmock Estuary.Services.EventRetrievalService.Mock, for: Estuary.Services.EventRetrievalServiceBehaviour
defmock Estuary.MessageHandler.Mock, for: Estuary.MessageHandlerBehaviour
defmock Prestige.Mock, for: Estuary.PrestigeBehaviour
defmock MockTable, for: Pipeline.Writer
defmock MockReader, for: Pipeline.Reader
