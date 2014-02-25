defmodule Router do
  use Phoenix.Router, port: 4000

  plug Plug.Static, at: "/static", from: :phoenix

  scope alias: Phoenix.Examples.Controllers do
    get "/pages/:page", Pages, :show, as: :page
    get "/files/*path", Files, :show, as: :file
    get "/profiles/user-:id", Users, :show

    resources "users", Users do
      resources "comments", Comments
    end

    raw_websocket "/echo", Eco
  end
end
