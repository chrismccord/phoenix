defmodule Phoenix.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn   = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path   = "/" <> Enum.join(conn.path_info, "/")

      %NoRouteError{message: "no route found for #{conn.method} #{path} (#{inspect router})",
                    conn: conn, router: router}
    end
  end

  @moduledoc """
  Defines the Phoenix router.

  A router is the heart of a Phoenix application. It has three
  main responsibilities:

    * It defines a plug pipeline responsible for handling
      upcoming requests and dispatching those requests to
      controllers and other plugs.

    * It hosts configuration for the router and related
      entities (like plugs).

    * It provides a wrapper for starting and stopping the
      router in a specific web server.

  We will explore those responsibilities next.

  ## Routing

  The router provides a set of macros for generating routes
  that dispatch to specific controllers and actions. Those
  macros are named after HTTP verbs. For example:

      defmodule MyApp.Router do
        use Phoenix.Router

        get "/pages/:page", PageController, :show
      end

  The `get/3` macro above accepts a request of format "/pages/VALUE" and
  dispatches it to the show action in the `PageController`.

  Phoenix's router is extremely efficient, as it relies on Elixir
  pattern matching for matching routes and serving requests.

  ### Helpers

  Phoenix automatically generates a module `Helpers` inside your router
  which contains named helpers to help developers generate and keep
  their routes up to date.

  Helpers are automatically generated based on the controller name.
  For example, the route:

      get "/pages/:page", PageController, :show

  will generate a named helper:

      MyApp.Router.Helpers.page_path(:show, "hello")
      "/pages/hello"

      MyApp.Router.Helpers.page_path(:show, "hello", some: "query")
      "/pages/hello?some=query"

  The named helper can also be customized with the `:as` option. Given
  the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the named helper will be:

      MyApp.Router.Helpers.special_page_path(:show, "hello")
      "/pages/hello"

  ### Scopes and Resources

  The router also supports scoping of routes:

      scope "/api/v1", as: :api_v1 do
        get "/pages/:id", PageController, :show
      end

  For example, the route above will match on the path `"/api/v1/pages/:id"
  and the named route will be `api_v1_page_path`, as expected from the
  values given to `scope/2` option.

  Phoenix also provides a `resources/4` macro that allows developers
  to generate "RESTful" routes to a given resource:

      defmodule MyApp.Router do
        use Phoenix.Router

        pipe_through :browser

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:destroy]
      end

  Finally, Phoenix ships with a `mix phoenix.routes` task that nicely
  formats all routes in a given router. We can use it to verify all
  routes included in the router above:

      $ mix phoenix.routes
      page_path  GET    /pages/:id       PageController.show/2
      user_path  GET    /users           UserController.index/2
      user_path  GET    /users/:id/edit  UserController.edit/2
      user_path  GET    /users/new       UserController.new/2
      user_path  GET    /users/:id       UserController.show/2
      user_path  POST   /users           UserController.create/2
      user_path  PATCH  /users/:id       UserController.update/2
                 PUT    /users/:id       UserController.update/2

  One can also pass a router explicitly as an argument to the task:

      $ mix phoenix.routes MyApp.Router

  Check `scope/2` and `resources/4` for more information.

  ## Pipelines and plugs

  Once a request arrives to the Phoenix router, it performs
  a series of transformations through pipelines until the
  request is dispatched to a desired end-point.

  Such transformations are defined via plugs, as defined
  in the [Plug](http://github.com/elixir-lang/plug) specification.
  Once a pipeline is defined, it can be piped through per scope.

  For example:

      defmodule MyApp.Router do
        use Phoenix.Router

        pipeline :browser do
          plug :fetch_session
          plug :accepts, ~w(html json)
        end

        scope "/" do
          pipe_through :browser

          # browser related routes and resources
        end
      end

  `Phoenix.Router` imports functions from both `Plug.Conn` and `Phoenix.Controller`
  to help define plugs. In the example above, `fetch_session/2`
  comes from `Plug.Conn` while `accepts/2` comes from `Phoenix.Controller`.

  By default, Phoenix ships with one pipeline, called `:before`,
  that is always invoked before any route matches. All other
  pipelines are invoked only after a specific route matches,
  but before the route is dispatched to.

  ### :before pipeline

  Those are the plugs in the `:before` pipeline in the order
  they are defined. How each plug is configured is defined in
  a later sections.

    * `Plug.Static` - serves static assets. Since this plug comes
      before the router, serving of static assets is not logged

    * `Plug.Logger` - logs incoming requests

    * `Plug.Parsers` - parses the request body when a known
      parser is available. By default parsers urlencoded,
      multipart and json (with poison). The request body is left
      untouched when the request content-type cannot be parsed

    * `Plug.MethodOverride` - converts the request method to
      `PUT`, `PATCH` or `DELETE` for `POST` requests with a
      valid `_method` parameter

    * `Plug.Head` - converts `HEAD` requests to `GET` requests and
      strips the response body

    * `Plug.Session` - a plug that sets up session management.
      Note that `fetch_session/2` must still be explicitly called
      before using the session as this plug just sets up how
      the session is fetched

    * `Phoenix.CodeReloader` - a plug that enables code reloading
      for all entries in the `web` directory. It is configured
      directly in the Phoenix application

  ### Customizing pipelines

  You can define new pipelines at any moment with the `pipeline/2`
  macro:

      pipeline :api do
        plug :token_authentication
      end

  And then in a scope (or at root):

      pipe_through [:api]

  In case you want to extend an existing pipeline, you can use the
  `extend/2` macro with a pipeline. For example, in order to add new
  plugs to the `:before` pipeline, one can do:

      extend :before do
        plug :authentication
      end

  ## Router configuration

  All routers are configured directly in the Phoenix application
  environment. For example:

      config :phoenix, YourApp.Router,
        secret_key_base: "kjoy3o1zeidquwy1398juxzldjlksahdk3"

  Phoenix configuration is split in two categories. Compile-time
  configuration means the configuration is read during compilation
  and changing it at runtime has no effect. Most of the compile-time
  configuration is related to pipelines and plugs.

  On the other hand, runtime configuration is accessed during or
  after your application is started and can be read through the
  `config/2` function:

      YourApp.Router.config(:port)
      YourApp.Router.config(:some_config, :default_value)

  ### Compile-time

    * `:session` - configures the `Plug.Session` plug. Defaults to
      `false` but can be set to a keyword list of options as defined
      in `Plug.Session`. For example:

          config :phoenix, YourApp.Router,
            session: [store: :cookie, key: "_your_app_key"]

    * `:parsers` - sets up the request parsers. Accepts a set of options
      as defined by `Plug.Parsers`. If parsers are disabled, parameters
      won't be explicitly fetched before matching a route and functionality
      dependent on parameters, like the `Plug.MethodOverride`, will be
      disabled too. Defaults to:

          [pass: ["*/*"],
           json_decoder: Poison,
           parsers: [:urlencoded, :multipart, :json]]

    * `:static` - sets up static assets serving. Accepts a set of options
      as defined by `Plug.Static`. Defaults to:

          [at: "/",
           from: Mix.Project.config[:app]]

    * `:debug_errors` - when true, uses `Plug.Debugger` functionality for
      debugging failures in the application. Recomended to be set to true
      only in development as it allows listing of the application source
      code during debugging. Defaults to false.

    * `:render_errors` - a module representing a view to render templates
      whenever there is a failure in the application. For example, if the
      application crashes with a 500 error during a HTML request,
      `render("500.html", assigns)` will be called in the view given to
      `:render_errors`. The default view is `MyApp.ErrorView`.

  ### Runtime

    * `:http` - the configuration for the http server. Currently uses
      cowboy and accepts all options as defined by `Plug.Adapters.Cowboy`.
      Defaults to false.

    * `:https` - the configuration for the https server. Currently uses
      cowboy and accepts all options as defined by `Plug.Adapters.Cowboy`.
      Defaults to false.

    * `:secret_key_base` - a secret key used as base to generate secrets
      to encode cookies, session and friends. Defaults to nil as it must
      be set per application.

    * `:url` - configuration for generating URLs throughout the app.
      Accepts the host, scheme and port. Defaults to:

          [host: "localhost"]

  ## Web server

  Starting a router as part of a web server can be done by invoking
  `YourApp.Router.start/0`. Stopping the router is done with
  `YourApp.Router.stop/0`. The web server is configured with the
  `:http` and `:https` options defined above.
  """

  alias Phoenix.Router.Adapter
  alias Phoenix.Router.Resource
  alias Phoenix.Router.Scope

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(_opts) do
    quote do
      unquote(prelude())
      unquote(plug())
      unquote(pipelines())
      unquote(server())
    end
  end

  defp prelude() do
    quote do
      @before_compile Phoenix.Router
      Module.register_attribute __MODULE__, :phoenix_routes, accumulate: true

      import Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller

      config = Adapter.config(__MODULE__)
      @config config

      # Set up initial scope
      @phoenix_pipeline nil
      Phoenix.Router.Scope.init(__MODULE__)
    end
  end

  defp plug() do
    {conn, pipeline} =
      [:dispatch, :match, :before]
      |> Enum.map(&{&1, [], true})
      |> Plug.Builder.compile()

    call =
      quote do
        unquote(conn) =
          unquote(conn)
          |> Plug.Conn.put_private(:phoenix_router, __MODULE__)
          |> Plug.Conn.put_private(:phoenix_pipelines, [])
        unquote(pipeline)
      end

    quote location: :keep do
      @behaviour Plug

      @doc """
      Callback required by Plug that initializes the router
      for serving web requests.
      """
      def init(opts) do
        opts
      end

      @doc """
      Callback invoked by Plug on every request.
      """

      # For debugging errors, we wrap each step in the pipeline
      # in isolation. This allows us to have fresh copies of the
      # connection as we go.
      if config[:debug_errors] do
        @debug_errors [otp_app: config[:otp_app]]

        def call(unquote(conn), opts) do
          Plug.Debugger.wrap(unquote(conn), @debug_errors, fn ->
            unquote(call)
          end)
        end

        defp match(conn, []) do
          Plug.Debugger.wrap(conn, @debug_errors, fn ->
            match(conn, conn.method, conn.path_info, conn.host)
          end)
        end

        defp dispatch(conn, []) do
          Plug.Debugger.wrap(conn, @debug_errors, fn ->
            conn.private.phoenix_route.(conn)
          end)
        end
      else
        def call(unquote(conn), opts) do
          unquote(call)
        end

        defp match(conn, []) do
          match(conn, conn.method, conn.path_info, conn.host)
        end

        defp dispatch(conn, []) do
          conn.private.phoenix_route.(conn)
        end
      end

      defoverridable [init: 1, call: 2]

      use Phoenix.Router.RenderErrors, view: config[:render_errors]
    end
  end

  defp pipelines() do
    quote do
      pipeline :before do
        if static = config[:static] do
          static = Keyword.merge([from: config[:otp_app]], static)
          plug Plug.Static, static
        end

        plug Plug.Logger

        if Application.get_env(:phoenix, :code_reloader) do
          plug Phoenix.CodeReloader
        end

        if parsers = config[:parsers] do
          plug Plug.Parsers, parsers
          plug Plug.MethodOverride
        end

        plug Plug.Head
        plug :put_secret_key_base

        if session = config[:session] do
          salt    = Atom.to_string(__MODULE__)
          session = Keyword.merge([signing_salt: salt, encryption_salt: salt], session)
          plug Plug.Session, session
        end
      end
    end
  end

  defp server() do
    quote location: :keep, unquote: false do
      @doc """
      Starts the current router for serving requests
      """
      def start() do
        Adapter.start(unquote(config[:otp_app]), __MODULE__)
      end

      @doc """
      Stops the current router from serving requests
      """
      def stop() do
        Adapter.stop(unquote(config[:otp_app]), __MODULE__)
      end

      @doc """
      Returns the router configuration for `key`

      Returns `default` if the router does not exist.
      """
      def config(key, default \\ nil) do
        case :ets.lookup(__MODULE__, key) do
          [{^key, val}] -> val
          [] -> default
        end
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    Phoenix.Router.Helpers.define(env, routes)

    pipelines =
      for {name, {line, pipelines}} <- Scope.pipelines(env.module) do
        {conn, body} = Plug.Builder.compile(pipelines)
        quote line: line do
          defp unquote(name)(unquote(conn), _), do: unquote(body)
        end
      end

    quote do
      @doc false
      def __routes__ do
        unquote(Macro.escape(routes))
      end

      defp match(conn, _method, _path_info, _host) do
        raise NoRouteError, conn: conn, router: __MODULE__
      end

      unquote(pipelines)

      # TODO: How is this customizable?
      # We can move it to the controller.
      defp put_secret_key_base(conn, _) do
        try do
          put_in conn.secret_key_base, config(:secret_key_base)
        rescue
          _ -> conn
        end
      end
    end
  end

  for verb <- @http_methods do
    method = verb |> to_string |> String.upcase
    @doc """
    Generates a route to handle a #{verb} request to the given path.
    """
    defmacro unquote(verb)(path, controller, action, options \\ []) do
      add_route(unquote(method), path, controller, action, options)
    end
  end

  defp add_route(verb, path, controller, action, options) do
    quote bind_quoted: binding() do
      route = Scope.route(__MODULE__, verb, path, controller, action, options)
      parts = {:%{}, [], route.binding}

      @phoenix_routes route

      defp match(var!(conn), unquote(route.verb), unquote(route.path_segments),
                 unquote(route.host_segments)) do
        var!(conn) =
          Plug.Conn.put_private(var!(conn), :phoenix_route, fn conn ->
            conn = update_in(conn.params, &Map.merge(&1, unquote(parts)))
            opts = unquote(route.controller).init(unquote(route.action))
            unquote(route.controller).call(conn, opts)
          end)
          |> Plug.Conn.put_private(:phoenix_pipelines, unquote(route.pipe_through))
        unquote(route.pipe_segments)
      end
    end
  end

  @doc """
  Defines a plug pipeline.

  Pipelines are defined at the router root and can be used
  from any scope.

  ## Examples

      pipeline :api do
        plug :token_authentication
        plug :dispatch
      end

  A scope may then use this pipeline as:

      scope "/" do
        pipe_through :api
      end

  Every time `pipe_through/1` is called, the new pipelines
  are appended to the ones previously given.
  """
  defmacro pipeline(pipeline, do: block) do
    pipeline(pipeline, block, :define)
  end

  @doc """
  Extends a previously defined pipeline.

  ## Examples

      extend :before do
        plug :authentication
      end
  """
  defmacro extend(pipeline, do: block) do
    pipeline(pipeline, block, :extend)
  end

  defp pipeline(pipeline, block, style) do
    quote do
      pipeline = unquote(pipeline)
      @phoenix_pipeline Scope.read_pipeline(__MODULE__, pipeline, unquote(style))
      unquote(block)
      Scope.write_pipeline(__MODULE__, pipeline, __ENV__.line, @phoenix_pipeline)
      @phoenix_pipeline nil
    end
  end

  @doc """
  Defines a plug inside a pipeline.

  See `pipeline/2` for more information.
  """
  defmacro plug(plug, opts \\ []) do
    quote do
      if pipeline = @phoenix_pipeline do
        @phoenix_pipeline [{unquote(plug), unquote(opts), true}|pipeline]
      else
        raise "cannot define plug at the router level, plug must be defined inside a pipeline"
      end
    end
  end

  @doc """
  Defines a pipeline to send the connection through.

  See `pipeline/2` for more information.
  """
  defmacro pipe_through(pipes) do
    quote do
      if pipeline = @phoenix_pipeline do
        raise "cannot pipe_through inside a pipeline"
      else
        Scope.pipe_through(__MODULE__, unquote(pipes))
      end
    end
  end

  @doc """
  Defines "RESTful" endpoints for a resource.

  The given definition:

      resources "/users", UserController

  will include routes to the following actions:

    * `GET /users` => `:index`
    * `GET /users/new` => `:new`
    * `POST /users` => `:create`
    * `GET /users/:id` => `:show`
    * `GET /users/:id/edit` => `:edit`
    * `PATCH /users/:id` => `:update`
    * `PUT /users/:id` => `:update`
    * `DELETE /users/:id` => `:destroy`

  ## Options

  This macro accepts a set of options:

    * `:only` - a list of actions to generate routes for, for example: `[:show, :edit]`
    * `:except` - a list of actions to exclude generated routes from, for example: `[:destroy]`
    * `:param` - the name of the paramter for this resource, defaults to `"id"`
    * `:name` - the prefix for this resource. This is used for the named helper
      and as the prefix for the parameter in nested resources. The default value
      is automatically derived from the controller name, i.e. `UserController` will
      have name `"user"`
    * `:as` - configures the named helper exclusively

  """
  defmacro resources(path, controller, opts, do: nested_context) do
    add_resources path, controller, opts, do: nested_context
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, do: nested_context) do
    add_resources path, controller, [], do: nested_context
  end

  defmacro resources(path, controller, opts) do
    add_resources path, controller, opts, do: nil
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller) do
    add_resources path, controller, [], do: nil
  end

  defp add_resources(path, controller, options, do: context) do
    quote do
      # TODO: Support :alias as option (which is passed to scope)
      resource = Resource.build(unquote(path), unquote(controller), unquote(options))

      parm = resource.param
      path = resource.path
      ctrl = resource.controller
      opts = [as: resource.as]

      Enum.each resource.actions, fn action ->
        case action do
          :index   -> get    "#{path}",               ctrl, :index, opts
          :show    -> get    "#{path}/:#{parm}",      ctrl, :show, opts
          :new     -> get    "#{path}/new",           ctrl, :new, opts
          :edit    -> get    "#{path}/:#{parm}/edit", ctrl, :edit, opts
          :create  -> post   "#{path}",               ctrl, :create, opts
          :destroy -> delete "#{path}/:#{parm}",      ctrl, :destroy, opts
          :update  ->
            patch "#{path}/:#{parm}", ctrl, :update, opts
            put   "#{path}/:#{parm}", ctrl, :update, as: nil
        end
      end

      scope resource.member do
        unquote(context)
      end
    end
  end

  @doc """
  Defines a scope in which routes can be nested.

  ## Examples

    scope "/api/v1", as: :api_v1, alias: API.V1 do
      get "/pages/:id", PageController, :show
    end

  The generated route above will match on the path `"/api/v1/pages/:id"
  and will dispatch to `:show` action in `API.V1.PageController`. A named
  helper `api_v1_page_path` will also be generated.

  ## Options

  The supported options are:

    * `:path` - a string containing the path scope
    * `:as` - a string or atom containing the named helper scope
    * `:alias` - an alias (atom) containing the controller scope
    * `:host` - a string containing the host scope, or prefix host scope, ie
                `"foo.bar.com"`, `"foo."`

  """
  defmacro scope(options, do: context) do
    do_scope(options, context)
  end

  @doc """
  Define a scope with the given path.

  This function is a shortcut for:

      scope path: path do
        ...
      end

  """
  defmacro scope(path, options, do: context) do
    options = quote do
      path = unquote(path)
      case unquote(options) do
        alias when is_atom(alias) -> [path: path, alias: alias]
        options when is_list(options) -> Keyword.put(options, :path, path)
      end
    end
    do_scope(options, context)
  end

  @doc """
  Define a scope with the given path and alias.

  This function is a shortcut for:

      scope path: path, alias: alias do
        ...
      end

  """
  defmacro scope(path, alias, options, do: context) do
    options = quote do
      unquote(options)
      |> Keyword.put(:path, unquote(path))
      |> Keyword.put(:alias, unquote(alias))
    end
    do_scope(options, context)
  end

  defp do_scope(options, context) do
    quote do
      Scope.push(__MODULE__, unquote(options))
      try do
        unquote(context)
      after
        Scope.pop(__MODULE__)
      end
    end
  end
end
