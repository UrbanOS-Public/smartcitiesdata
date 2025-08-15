# Code Unit Inventory

## `lib/discovery_api_web/controllers/data_controller.ex`

This controller handles data retrieval for datasets. It defines actions for querying, previewing, and generating presigned URLs for downloads. Plugs are used to manage model access and response caching.

## `lib/discovery_api/event/event_handler.ex`

This module is responsible for handling various system events. It logs event reception and uses pattern matching to delegate different event types to specific handlers. The primary focus is on processing dataset updates and managing cache invalidation.

## `lib/discovery_api_web/controllers/multiple_data_controller.ex`

This controller manages queries that can affect multiple datasets. It provides a `query` action that takes an SQL statement and returns the results in various formats. The controller ensures the user is authorized to access all datasets involved in the query.

## `lib/discovery_api_web/plugs/get_model.ex`

This plug is responsible for fetching a dataset model based on request parameters. It can retrieve the model using either a dataset ID or a combination of organization and dataset names. The fetched model is then added to the connection assigns for downstream use.

## `lib/discovery_api_web/controllers/data_download_controller.ex`

This controller handles direct file downloads for datasets. It retrieves the dataset model and initiates a download stream for the requested file. The controller uses plugs to ensure the user has the necessary access permissions.

## `lib/discovery_api_web.ex`

This is the main entry point for the web interface of the Discovery API. It defines the core functionalities for controllers, views, and other web-related components. It also imports necessary modules and sets up aliases for easier access throughout the application.

## `lib/discovery_api_web/auth/error_handler.ex`

This module handles authentication errors within the application. It implements the `Guardian.ErrorHandler` behavior to respond to unauthorized access attempts. The primary function is to render a JSON error message when authentication fails.

## `lib/discovery_api_web/auth/token_handler.ex`

This module is responsible for handling authentication tokens. It implements the `Guardian.Token` behavior for creating, verifying, and managing JWTs. It also includes functionality for storing and retrieving tokens from the connection.

## `lib/discovery_api_web/channels/user_socket.ex`

This module defines the user socket for real-time communication. It handles socket connections, authentication, and channel subscriptions. The socket is used to push updates and notifications to connected clients.

## `lib/discovery_api_web/controllers/api_key_controller.ex`

This controller manages API key operations for users. It provides an action to regenerate a user's API key, ensuring that the user is authenticated before performing the action. The new API key is then returned in the response.

## `lib/discovery_api_web/controllers/data_json_controller.ex`

This controller is responsible for serving the `data.json` file. It defines a `show` action that retrieves the file path from the `DataJsonService` and sends it as a response. Error handling is included for cases where the file cannot be accessed.

## `lib/discovery_api_web/controllers/metadata_controller.ex`

This controller handles requests for dataset metadata. It provides actions to fetch details, schema, metrics, and statistics for a given dataset. Plugs are used to retrieve the dataset model and enforce access restrictions.

## `lib/discovery_api_web/controllers/organization_controller.ex`

This controller manages organization-related requests. It defines an action to fetch the details of a specific organization by its ID. The controller renders the organization's information or returns a "Not Found" error if the organization does not exist.

## `lib/discovery_api_web/controllers/recommendation_controller.ex`

This controller provides dataset recommendations. It uses a plug to fetch the relevant dataset model and then calls the `RecommendationEngine` to get a list of recommended datasets. The recommendations are returned as a JSON response.

## `lib/discovery_api_web/controllers/search_controller.ex`

This controller handles advanced search functionality for datasets. It builds search queries based on user-provided parameters, including keywords, facets, and sorting options. The controller interacts with the Elasticsearch search service to retrieve and render the search results.

## `lib/discovery_api_web/controllers/tableau_controller.ex`

This controller provides endpoints for Tableau integration. It includes actions to fetch table information and describe query schemas, which are used to populate the Tableau connector. The controller ensures that users are authorized to access the requested data.

## `lib/discovery_api_web/controllers/user_controller.ex`

This controller manages user authentication state. It provides actions for handling user login and logout events. The `logged_in` action creates a user session, while the `logged_out` action clears it.

## `lib/discovery_api_web/controllers/visualization_controller.ex`

This controller handles CRUD operations for visualizations. It allows authenticated users to create, view, update, and delete their visualizations. The controller also enforces ownership and access controls for all actions.

## `lib/discovery_api_web/endpoint.ex`

This module is the entry point for all HTTP requests. It defines the application's socket, plugs, and other endpoint configurations. It also handles static file serving and code reloading in the development environment.

## `lib/discovery_api_web/gettext.ex`

This module provides internationalization and localization support. It uses the Gettext library to enable translation of strings throughout the application. This allows the user interface to be displayed in multiple languages.

## `lib/discovery_api_web/plugs/acceptor.ex`

This plug provides an alternative to Phoenix's default `:accept` plug. It parses the `accept` header of incoming requests to determine the requested format. This allows for more flexible content negotiation.

## `lib/discovery_api_web/plugs/no_store.ex`

This plug sets response headers to prevent client-side caching. It adds `cache-control` and `pragma` headers to ensure that the response is not stored by browsers or proxies. This is useful for sensitive data or frequently changing content.

## `lib/discovery_api_web/plugs/record_metrics.ex`

This plug records API usage metrics. It identifies the action being performed and the dataset being accessed, then logs the hit using the `MetricsService`. This helps in monitoring API traffic and understanding usage patterns.

## `lib/discovery_api_web/plugs/response_cache.ex`

This plug provides response caching to improve performance. It caches the entire response body for specific URL patterns and serves subsequent requests from the cache. The cache can be invalidated to force a fresh response.

## `lib/discovery_api_web/plugs/restrictor.ex`

This plug enforces access restrictions on datasets. It checks if the current user or API key has permission to access the requested model. If access is denied, it halts the connection and returns a "Not Found" error.

## `lib/discovery_api_web/plugs/secure_headers.ex`

This plug adds various security-related headers to the HTTP response. It helps to protect the application from common web vulnerabilities, such as cross-site scripting (XSS) and clickjacking. The headers are configured to enforce modern security policies.

## `lib/discovery_api_web/plugs/set_allowed_origin.ex`

This plug determines if the request's origin is allowed. It checks the `origin` header against a list of allowed domains and assigns a boolean to the connection. This is used to enforce Cross-Origin Resource Sharing (CORS) policies.

## `lib/discovery_api_web/plugs/set_current_user.ex`

This plug sets the current user on the connection. It retrieves the user resource from the Guardian authentication token and assigns it to the connection for use in other parts of the application. It also handles API key authentication as a fallback.

## `lib/discovery_api_web/render_error.ex`

This module provides a centralized way to render error responses. It takes a status code and a message, then renders a JSON error view with the appropriate information. This ensures consistent error formatting across the API.

## `lib/discovery_api_web/router.ex`

This module defines all the API routes and their corresponding controllers and actions. It uses pipelines to apply plugs for authentication, authorization, and other concerns. The router is responsible for dispatching incoming requests to the correct handler.

## `lib/discovery_api_web/utilities/access_utils.ex`

This module defines a behavior for checking access to datasets. It specifies a callback `has_access?/2` that should be implemented by other modules to define their own access control logic. This allows for a pluggable and consistent approach to authorization.

## `lib/discovery_api_web/utilities/describe_utils.ex`

This module provides utility functions for describing data schemas. It converts the output of a `DESCRIBE` query into a more user-friendly format. The module is used to translate database types into standardized data types for the API.

## `lib/discovery_api_web/utilities/geojson_utils.ex`

This module contains utility functions for working with GeoJSON data. It includes a function to calculate the bounding box of a set of GeoJSON features. This is useful for providing spatial context to geographic datasets.

## `lib/discovery_api_web/utilities/hmac_token.ex`

This module provides functions for creating and validating HMAC tokens. These tokens are used to secure presigned URLs, ensuring that they are not tampered with and that they expire after a certain time. The module uses a secret key to sign the tokens.

## `lib/discovery_api_web/utilities/json_field_decoder.ex`

This module provides a utility for decoding JSON fields within a dataset. It recursively processes a schema and decodes any fields marked as JSON. This is used to ensure that nested JSON data is correctly parsed and handled.

## `lib/discovery_api_web/utilities/model_access_utils.ex`

This module implements the `AccessUtils` behavior for Ecto-based authorization rules. It checks if a user or API key has access to a private dataset by querying the Raptor service. Public datasets are accessible to everyone.

## `lib/discovery_api_web/utilities/model_sorter.ex`

This module provides functions for sorting dataset models. It supports sorting by name in ascending or descending order, as well as by last modification date. The sorter handles different date fields based on the dataset's source type.

## `lib/discovery_api_web/utilities/param_utils.ex`

This module contains utility functions for extracting and converting request parameters. It provides a safe way to parse integers from params, with a default value if the parsing fails. This helps to prevent errors from invalid user input.

## `lib/discovery_api_web/utilities/query_access_utils.ex`

This module provides helper methods for authorizing SQL queries. It determines which datasets are affected by a query and checks if the user or API key has access to all of them. It also provides a way to get an authorized Presto session.

## `lib/discovery_api_web/utilities/stream_utils.ex`

This module provides utilities for streaming data. It includes functions for converting a data stream to CSV format and for sending chunked responses. The module is used to efficiently handle large datasets without loading them entirely into memory.

## `lib/discovery_api_web/views/api_key_view.ex`

This view is responsible for rendering the response for API key regeneration. It takes the new API key and formats it into a JSON object. This provides a consistent structure for the API key endpoint.

## `lib/discovery_api_web/views/data_view.ex`

This view handles the rendering of dataset data in various formats. It supports CSV, JSON, and GeoJSON, and can render both static and streamed data. The view is responsible for formatting the data correctly for each content type.

## `lib/discovery_api_web/views/error_helpers.ex`

This module provides helper functions for translating and building error messages. It integrates with the Gettext library to provide internationalized error messages. This is used to ensure that error messages are user-friendly and localized.

## `lib/discovery_api_web/views/error_view.ex`

This view is responsible for rendering error responses. It can render errors in JSON or CSV format, providing a consistent error structure. The view also includes a fallback for unhandled templates, ensuring that all errors are handled gracefully.

## `lib/discovery_api_web/views/metadata_view.ex`

This view renders dataset metadata. It provides a detailed JSON representation of a dataset, including its schema, organization details, and other attributes. The view is used to present a comprehensive overview of a dataset.

## `lib/discovery_api_web/views/multiple_data_view.ex`

This view is responsible for rendering data from multiple datasets. It supports various formats, including CSV, JSON, and GeoJSON, and can handle streamed responses. The view is used for presenting the results of complex queries that span multiple tables.

## `lib/discovery_api_web/views/organization_view.ex`

This view renders organization details. It takes an organization object and formats it into a JSON response. The view is used to provide a standardized representation of an organization's information.

## `lib/discovery_api_web/views/search_view.ex`

This view is responsible for rendering search results. It takes a list of dataset models, facets, and pagination information, and formats them into a JSON response. The view provides a structured and consistent format for search results.

## `lib/discovery_api_web/views/tableau_view.ex`

This view renders data for the Tableau connector. It provides a JSON representation of table information, which is used by Tableau to understand the available data. The view is essential for enabling Tableau integration.

## `lib/discovery_api_web/views/visualization_view.ex`

This view is responsible for rendering visualizations. It provides a JSON representation of a single visualization or a list of visualizations. The view also includes information about the allowed actions for each visualization.

## `lib/discovery_api.ex`

This module provides top-level configuration and helper functions for the Discovery API application. It defines the application's instance name and provides access to the Prestige session options. This serves as a central point for application-wide settings.

## `lib/discovery_api/application.ex`

This module is the main entry point for the Discovery API application. It starts and supervises all the necessary processes, including the web endpoint, database repository, and other background services. It also handles application configuration and environment variable loading.

## `lib/discovery_api/data/cache_populator.ex`

This module is a GenServer responsible for prepopulating the `SystemNameCache` at application startup. It fetches all dataset models from the Brook view state and populates the cache with their system names. This ensures that the cache is warm and ready for requests.

## `lib/discovery_api/data/data_json.ex`

This module is responsible for generating the `data.json` file, which conforms to the Project Open Data schema. It fetches all public, non-remote datasets and translates them into the required format. This file provides a machine-readable catalog of the available data.

## `lib/discovery_api/data/mapper.ex`

This module handles the mapping of data between different structures. It provides a function to convert a `SmartCity.Dataset` into a `DiscoveryApi.Data.Model`. This is crucial for integrating with other parts of the Smart Cities data ecosystem.

## `lib/discovery_api/data/model.ex`

This module defines the `Model` struct, which represents a dataset in the Discovery API. It provides functions for creating, retrieving, and deleting dataset models. The module also includes helpers for adding system attributes and converting models to other formats.

## `lib/discovery_api/data/organization_details.ex`

This module defines the `OrganizationDetails` struct. This struct holds information about an organization, such as its name, title, and logo. It is used to provide consistent organization data throughout the application.

## `lib/discovery_api/data/persistence.ex`

This module provides a generic interface for persisting and retrieving data from Redis. It offers functions for getting, setting, and deleting keys, as well as for fetching multiple keys at once. This abstracts the details of Redis communication.

## `lib/discovery_api/data/system_name_cache.ex`

This module provides a cache for mapping system names to dataset IDs. It uses Cachex to store the mappings, which improves performance by avoiding repeated lookups. The cache is populated at application startup and updated as needed.

## `lib/discovery_api/data/table_info_cache.ex`

This module provides a cache for table information used by the Tableau connector. It stores the table schemas, which helps to speed up the connector's initialization. The cache can be invalidated to force a refresh of the table information.

## `lib/discovery_api/data/visualization_migrator.ex`

This module is a GenServer that ensures all derived fields of visualizations are up to date. It runs as a transient process, migrating any visualizations that need updating. This is useful for applying data model changes to existing records.

## `lib/discovery_api/quantum/scheduler.ex`

This module defines a scheduler for running periodic tasks. It uses the Quantum library to allow for scheduling arbitrary functions from the application's configuration. This is used for running background jobs like cache invalidation or data updates.

## `lib/discovery_api/recommendation_engine.ex`

This module provides a recommendation engine for datasets. It saves dataset metadata and uses it to find similar datasets based on shared schema columns. The engine is used to suggest related datasets to users.

## `lib/discovery_api/release_tasks.ex`

This module contains tasks to be run during the application's release process. Its main function is to apply Ecto database migrations, ensuring that the database schema is up to date with the latest code.

## `lib/discovery_api/repo.ex`

This module is the Ecto repository for the Discovery API. It provides a wrapper around the database adapter and is used for all database operations. It is configured to use the PostgreSQL adapter.

## `lib/discovery_api/schemas/generators.ex`

This module provides functions for generating unique public IDs. It uses the Nanoid library to create short, URL-friendly IDs. This is used to create public identifiers for resources like visualizations.

## `lib/discovery_api/schemas/organizations.ex`

This module provides an interface for reading and writing organization data. It includes functions for creating, updating, and retrieving organizations from the database. It also handles the mapping from `SmartCity.Organization` structs.

## `lib/discovery_api/schemas/users.ex`

This module provides an interface for reading and writing user data. It includes functions for creating, updating, and retrieving users, as well as for associating users with organizations. It serves as the primary entry point for user-related database operations.

## `lib/discovery_api/schemas/users/organization.ex`

This module defines the Ecto schema for an organization. It specifies the fields and associations for the `organizations` table. The schema includes a many-to-many relationship with users.

## `lib/discovery_api/schemas/users/user_organization.ex`

This module defines the Ecto schema for the join table between users and organizations. It represents the many-to-many association between the two entities. This schema is used to manage user memberships in organizations.

## `lib/discovery_api/schemas/users/user.ex`

This module defines the Ecto schema for a user. It includes fields for the user's subject ID, name, and email, as well as associations with visualizations and organizations. The schema is used to map user data to the database.

## `lib/discovery_api/schemas/visualizations.ex`

This module provides an interface for reading and writing visualization data. It includes functions for creating, deleting, and retrieving visualizations, as well as for updating them. It also handles the association of visualizations with the datasets they use.

## `lib/discovery_api/schemas/visualizations/visualization.ex`

This module defines the Ecto schema for a data visualization. It includes fields for the visualization's public ID, query, title, and chart data. The schema also defines the association with the user who owns the visualization.

## `lib/discovery_api/search/elasticsearch/dataset_index.ex`

This module manages the Elasticsearch index for datasets. It provides functions for creating, deleting, and checking the existence of the index. This is a critical component for enabling search functionality.

## `lib/discovery_api/search/elasticsearch/document.ex`

This module handles CRUD operations for dataset documents in Elasticsearch. It provides functions for getting, updating, replacing, and deleting documents. It also includes a function for bulk-loading datasets into the index.

## `lib/discovery_api/search/elasticsearch/query_builder.ex`

This module is responsible for building Elasticsearch query bodies. It takes a set of search options and constructs a JSON query that can be sent to the Elasticsearch cluster. The builder supports various query types, including full-text search, filtering, and aggregations.

## `lib/discovery_api/search/elasticsearch/search.ex`

This module manages the execution of Elasticsearch queries and the formatting of their responses. It provides a `search` function that takes search options, builds a query, and returns the results. The module is the primary interface for the search functionality.

## `lib/discovery_api/search/elasticsearch/shared.ex`

This module provides shared functionality for the Elasticsearch modules. It includes helper functions for accessing the Elasticsearch configuration and for handling responses from the Elasticsearch client. This helps to reduce code duplication.

## `lib/discovery_api/services/auth_service.ex`

This module provides an interface for calling remote authentication services. It includes a function for creating a logged-in user by fetching user information from an external endpoint. This is used to integrate with the central authentication system.

## `lib/discovery_api/services/data_json_service.ex`

This module is responsible for managing the `data.json` file. It provides functions for creating, deleting, and ensuring the existence of the file. This service is used to provide a static, machine-readable catalog of the available data.

## `lib/discovery_api/services/metrics_service.ex`

This module is responsible for collecting and recording application metrics. It provides functions for tracking CSV downloads, data queries, and API hits. The metrics are recorded to Telemetry, which can be integrated with monitoring tools like Prometheus.

## `lib/discovery_api/services/object_storage_service.ex`

This module provides an interface for accessing files stored in an object storage service, such as AWS S3. It includes a function for downloading a file as a stream, which is useful for handling large files. The service is configured with the bucket name and region.

## `lib/discovery_api/services/presto_service.ex`

This module provides an interface for interacting with the Presto query engine. It includes functions for previewing data, checking if a statement is a `SELECT` query, and getting the tables affected by a query. It also provides helpers for building and validating SQL queries.

## `lib/discovery_api/stats/completeness.ex`

This module is responsible for calculating data completeness statistics. It provides a function that takes a dataset and a row of data, and returns an updated map of completeness statistics. The module recursively calculates statistics for nested data structures.

## `lib/discovery_api/stats/completeness_totals.ex`

This module provides an interface for calculating the total completeness score for a dataset. It takes a map of field-level completeness statistics and calculates a single score based on the number of required and optional fields.

## `lib/discovery_api/stats/stats_calculator.ex`

This module provides an interface for calculating statistics for all datasets. It includes a function to produce completeness stats for all non-remote datasets that have been updated since the last calculation. The results are saved to Redis.
