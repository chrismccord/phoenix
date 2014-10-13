Code.require_file "view/views.exs", __DIR__
Code.require_file "view/views/user_view.exs", __DIR__
Code.require_file "view/views/profile_view.exs", __DIR__
Code.require_file "view/views/layout_view.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case, async: true
  alias Phoenix.UserTest.UserView
  alias Phoenix.UserTest.LayoutView
  alias Phoenix.View

  doctest Phoenix.View, except: [render: 3]

  test "subviews render templates with imported functions from base view" do
    assert View.render(UserView, "base.html", name: "chris") == "<div>\n  Base CHRIS\n</div>\n\n"
  end

  test "subviews render templates with imported functions from subview" do
    assert View.render(UserView, "sub.html", desc: "truncated") == "Subview truncat...\n"
  end

  test "views can be render within another view, such as layouts" do
    html = View.render(UserView, "sub.html",
      desc: "truncated",
      title: "Test",
      within: {LayoutView, "application.html"}
    )

    assert html == "<html>\n  <title>Test</title>\n  Subview truncat...\n\n</html>\n"
  end

  test "views can render other views within template without safing" do
    html = View.render(UserView, "show.html", name: "<em>chris</em>")
    assert html == "Showing User <b>name:</b> &lt;em&gt;chris&lt;/em&gt;\n\n"
  end

  test "views can render local templates without safing" do
    html = View.render(UserView, "local_render.html", [])
    assert html == "Local Render Subview Hello...\n\n"
  end

  test "template_path_from_view_module finds the template path given view module" do
    assert View.template_path_from_view_module(MyApp.UserView, "web/templates") ==
      "web/templates/user"

    assert View.template_path_from_view_module(MyApp.Admin.UserView, "web/templates") ==
      "web/templates/admin/user"
  end

  test "default_templates_root/0 returns the default template path based on current mix project" do
    assert String.contains?(View.default_templates_root, "web/templates")
  end

  test "views have phoenix_recompile?/0 injected" do
    refute UserView.phoenix_recompile?
  end
end

