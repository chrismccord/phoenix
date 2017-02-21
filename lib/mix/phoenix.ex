defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @valid_attributes [:integer, :float, :decimal, :boolean, :map, :string,
                     :array, :references, :text, :date, :time,
                     :naive_datetime, :utc_datetime, :uuid, :binary]


  @doc """
  Evals EEx files from source dir.

  Files are evaluated against EEx according to
  the given binding.
  """
  def eval_from(apps, source_file_path, binding) do
    sources = Enum.map(apps, &to_app_source(&1, source_file_path))

    content =
      Enum.find_value(sources, fn source ->
        File.exists?(source) && File.read!(source)
      end) || raise "could not find #{source_file_path} in any of the sources"

    EEx.eval_string(content, binding)
  end

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def copy_from(apps, source_dir, target_dir, binding, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, source_file_path, target_file_path} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      target = Path.join(target_dir, target_file_path)

      case format do
        :text -> Mix.Generator.create_file(target, File.read!(source))
        :eex  -> Mix.Generator.create_file(target, EEx.eval_file(source, binding))
        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, EEx.eval_file(source, binding))
          end
      end
    end
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)
  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)

  @doc """
  Inflect path, scope, alias and more from the given name.

      iex> Mix.Phoenix.inflect("user")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       web_module: "Phoenix.Web",
       module: "Phoenix.User",
       scoped: "User",
       singular: "user",
       path: "user"]

      iex> Mix.Phoenix.inflect("Admin.User")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       web_module: "Phoenix.Web",
       module: "Phoenix.Admin.User",
       scoped: "Admin.User",
       singular: "user",
       path: "admin/user"]

      iex> Mix.Phoenix.inflect("Admin.SuperUser")
      [alias: "SuperUser",
       human: "Super user",
       base: "Phoenix",
       web_module: "Phoenix.Web",
       module: "Phoenix.Admin.SuperUser",
       scoped: "Admin.SuperUser",
       singular: "super_user",
       path: "admin/super_user"]
  """
  def inflect(singular) do
    base       = Mix.Phoenix.base
    web_module = Module.concat(base, "Web") |> inspect
    scoped     = Phoenix.Naming.camelize(singular)
    path       = Phoenix.Naming.underscore(scoped)
    singular   = String.split(path, "/") |> List.last
    module     = Module.concat(base, scoped) |> inspect
    alias      = String.split(module, ".") |> List.last
    human      = Phoenix.Naming.humanize(singular)

    [alias: alias,
     human: human,
     base: base,
     web_module: web_module,
     module: module,
     scoped: scoped,
     singular: singular,
     path: path]
  end

  @doc """
  Parses the attrs as received by generators.
  """
  def attrs(attrs) do
    Enum.map(attrs, fn attr ->
      attr
      |> drop_unique()
      |> String.split(":", parts: 3)
      |> list_to_attr()
      |> validate_attr!()
    end)
  end

  @doc """
  Generates some sample params based on the parsed attributes.
  """
  def params(attrs, action \\ :create) when action in [:create, :update] do
    attrs
    |> Enum.reject(fn
        {_, {:references, _}} -> true
        {_, _} -> false
       end)
    |> Enum.into(%{}, fn {k, t} -> {k, type_to_default(k, t, action)} end)
  end

  @doc """
  Checks the availability of a given module name.
  """
  def check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        namespace: My.App

  """
  def base do
    app = otp_app()

    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string |> Phoenix.Naming.camelize()
      mod  -> mod |> inspect()
    end
  end

  @doc """
  Returns the otp app from the Mix project configuration.
  """
  def otp_app do
    Mix.Project.config |> Keyword.fetch!(:app)
  end

  @doc """
  Returns all compiled modules in a project.
  """
  def modules do
    Mix.Project.compile_path
    |> Path.join("*.beam")
    |> Path.wildcard
    |> Enum.map(&beam_to_module/1)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  defp drop_unique(info) do
    prefix = byte_size(info) - 7
    case info do
      <<attr::size(prefix)-binary, ":unique">> -> attr
      _ -> info
    end
  end

  defp list_to_attr([key]), do: {String.to_atom(key), :string}
  defp list_to_attr([key, value]), do: {String.to_atom(key), String.to_atom(value)}
  defp list_to_attr([key, comp, value]) do
    {String.to_atom(key), {String.to_atom(comp), String.to_atom(value)}}
  end

  defp type_to_default(key, t, :create) do
    case t do
        {:array, _}     -> []
        :integer        -> 42
        :float          -> "120.5"
        :decimal        -> "120.5"
        :boolean        -> true
        :map            -> %{}
        :text           -> "some #{key}"
        :date           -> %{year: 2010, month: 4, day: 17}
        :time           -> %{hour: 14, minute: 0, second: 0}
        :uuid           -> "7488a646-e31f-11e4-aace-600308960662"
        :utc_datetime   -> %{year: 2010, month: 4, day: 17, hour: 14, minute: 0, second: 0}
        :naive_datetime -> %{year: 2010, month: 4, day: 17, hour: 14, minute: 0, second: 0}
        _               -> "some #{key}"
    end
  end
  defp type_to_default(key, t, :update) do
    case t do
        {:array, _}     -> []
        :integer        -> 43
        :float          -> "456.7"
        :decimal        -> "456.7"
        :boolean        -> false
        :map            -> %{}
        :text           -> "some updated #{key}"
        :date           -> %{year: 2011, month: 5, day: 18}
        :time           -> %{hour: 15, minute: 1, second: 1}
        :uuid           -> "7488a646-e31f-11e4-aace-600308960668"
        :utc_datetime   -> %{year: 2011, month: 5, day: 18, hour: 15, minute: 1, second: 1}
        :naive_datetime -> %{year: 2011, month: 5, day: 18, hour: 15, minute: 1, second: 1}
        _               -> "some updated #{key}"
    end
  end

  defp validate_attr!({_name, type} = attr) when type in @valid_attributes, do: attr
  defp validate_attr!({_name, {type, _}} = attr) when type in @valid_attributes, do: attr
  defp validate_attr!({_, type}) do
    Mix.raise "Unknown type `#{type}` given to generator. " <>
              "The supported types are: #{@valid_attributes |> Enum.sort() |> Enum.join(", ")}"
  end

  @doc """
  The paths to look for template files for generators.

  Defaults to checking the current app's priv directory,
  and falls back to phoenix's priv directory.
  """
  def generator_paths do
    [".", :phoenix]
  end

  def in_single?(path) do
    mixfile = Path.join(path, "mix.exs")
    apps_path = Path.join(path, "apps")

    File.exists?(mixfile) and not File.exists?(apps_path)
  end

  def in_umbrella?(app_path) do
    try do
      umbrella = Path.expand(Path.join [app_path, "..", ".."])
      File.exists?(Path.join(umbrella, "mix.exs")) &&
        Mix.Project.in_project(:umbrella_check, umbrella, fn _ ->
          path = Mix.Project.config[:apps_path]
          path && Path.expand(path) == Path.join(umbrella, "apps")
        end)
    catch
      _, _ -> false
    end
  end

  def web_prefix do
    if in_single?(File.cwd!()) do
      "lib/web"
    else
      "lib"
    end
  end

  def test_prefix do
    if in_single?(File.cwd!()) do
      "test/web"
    else
      "test"
    end
  end
end
