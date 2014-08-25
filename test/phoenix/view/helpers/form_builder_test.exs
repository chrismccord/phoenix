defmodule FormView do
  require EEx
  import Phoenix.View.Helpers.FormBuilder

  EEx.function_from_string :def, :render, """
  <%= form_for @user, [action: "/users"], fn f ->  %>
    <%= "Hey there" %>
    <%= text_field f, :id, value: nil %>
    <%= text_field f, :name %>
  <% end %>
  """, [:assigns]
end

defmodule Phoenix.View.Helpers.FormBuilderTest do
  use ExUnit.Case, async: true

  import Phoenix.View.Helpers.FormBuilder

  defmodule User do
    @derive [Access]
    defstruct id: nil, name: nil
  end

  test "form_tag" do
    user = %User{id: 1, name: "José Valim"}
    assert form_tag(user, [action: "/users"], do: "Hello") ==
      ~s(<form action="/users">Hello</form>)
  end

  test "rendered from EEx" do
    user = %User{id: 1, name: "José Valim"}
    view = FormView.render([user: user])
    assert view == ~S"""
    <form action="/users" method="post">
      Hey there
      <input name="user[id]" type="text" value="1">
      <input name="user[name]" type="text" value="José Valim">
    </form>
    """
  end
end

