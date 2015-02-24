defmodule Phoenix.HTML.Tag do
  @moduledoc ~S"""
  Helpers related to producing HTML tags within templates.
  """

  import Phoenix.HTML

  @tag_prefixes [:aria, :data]

  @doc ~S"""
  Creates an HTML tag with the given name and options.

      iex> tag(:br)
      {:safe, "<br>"}
      iex> tag(:input, type: "text", name: "user_id")
      {:safe, "<input name=\"user_id\" type=\"text\">"}
  """
  def tag(name), do: tag(name, [])
  def tag(name, attrs) when is_list(attrs) do
    {:safe, "<#{name}#{build_attrs(name, attrs)}>"}
  end

  @doc ~S"""
  Creates an HTML tag with given name, content, and attributes.

      iex> content_tag(:p, "Hello")
      {:safe, "<p>Hello</p>"}
      iex> content_tag(:p, "<Hello>", class: "test")
      {:safe, "<p class=\"test\">&lt;Hello&gt;</p>"}

      iex> content_tag :p, class: "test" do
      ...>   "Hello"
      ...> end
      {:safe, "<p class=\"test\">Hello</p>"}
  """
  def content_tag(name, content) when is_atom(name) do
    content_tag(name, content, [])
  end

  def content_tag(name, attrs, [do: block]) when is_atom(name) and is_list(attrs) do
    content_tag(name, block, attrs)
  end

  def content_tag(name, content, attrs) when is_atom(name) and is_list(attrs) do
    tag(name, attrs)
    |> safe_concat(content)
    |> safe_concat({:safe, "</#{name}>"})
  end

  @doc ~S"""
  Creates an HTML input field with the given type and options.

      iex> input_tag(:text, name: "name")
      {:safe, "<input name=\"name\" type=\"text\">"}
  """
  def input_tag(type, opts \\ []) when is_atom(type) do
    tag(:input, Keyword.put_new(opts, :type, type))
  end

  defp tag_attrs([]), do: ""
  defp tag_attrs(attrs) do
    for {k, v} <- attrs, into: "" do
      " " <> dasherize(k) <> "=" <> "\"" <> html_escape(v) <> "\""
    end
  end

  defp nested_attrs(attr, dict, acc) do
    Enum.reduce dict, acc, fn {k,v}, acc ->
      attr_name = "#{attr}-#{dasherize(k)}"
      case is_list(v) do
        true  -> nested_attrs(attr_name, v, acc)
        false -> [{attr_name, v}|acc]
      end
    end
  end

  defp build_attrs(_tag, []), do: ""
  defp build_attrs(tag, attrs), do: build_attrs(tag, attrs, [])

  defp build_attrs(_tag, [], acc),
    do: acc |> Enum.sort |> tag_attrs
  defp build_attrs(tag, [{k,v}|t], acc) when k in @tag_prefixes and is_list(v),
    do: build_attrs(tag, t, nested_attrs(k, v, acc))
  defp build_attrs(tag, [{k,true}|t], acc),
    do: build_attrs(tag, t, [{k,k}|acc])
  defp build_attrs(tag, [{k,v}|t], acc),
    do: build_attrs(tag, t, [{k,v}|acc])

  defp dasherize(value) when is_atom(value),   do: dasherize(Atom.to_string(value))
  defp dasherize(value) when is_binary(value), do: String.replace(value, "_", "-")
end
