import assert from "assert"

import jsdom from "jsdom"
import { WebSocket, Server as WebSocketServer } from "mock-socket"

import {Socket} from "../static/js/phoenix"

let socket

describe("protocol", () => {
  before(() => {
    socket = new Socket("/socket")
  })

  it("returns wss when location.protocal is https", () => {
    jsdom.changeURL(window, "https://example.com/");

    assert.equal(socket.protocol(), "wss")
  })

  it("returns ws when location.protocal is http", () => {
    jsdom.changeURL(window, "http://example.com/");

    assert.equal(socket.protocol(), "ws")
  })
})

describe("endpointURL", () => {
  it("returns endpoint for given full url", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("wss://example.org/chat")

    assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given protocol-relative url", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("//example.org/chat")

    assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given path on https host", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("/socket")

    assert.equal(socket.endPointURL(), "wss://example.com/socket/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given path on http host", () => {
    jsdom.changeURL(window, "http://example.com/");
    socket = new Socket("/socket")

    assert.equal(socket.endPointURL(), "ws://example.com/socket/websocket?vsn=1.0.0")
  })
})

describe("connect with WebSocket", () => {
  let mockServer

  before(() => {
    jsdom.changeURL(window, "http://example.com/");
    mockServer = new WebSocketServer('wss://example.com/')
  })

  after(() => {
    mockServer.stop()
  })

  describe("establishes websocket connection with endpoint", () => {
    const mockServer = new WebSocketServer('wss://example.com/')

    socket = new Socket("/socket")
    socket.connect()

    let conn = socket.conn
    assert.ok(conn instanceof WebSocket)
    assert.equal(conn.url, socket.endPointURL())
  })

  describe("sets callbacks for connection", () => {
    socket = new Socket("/socket")
    let opens = 0
    socket.onOpen(() => ++opens)
    let closes = 0
    socket.onClose(() => ++closes)
    let lastError
    socket.onError((error) => lastError = error)
    let lastMessage
    socket.onMessage((message) => lastMessage = message.payload)

    socket.connect()

    socket.conn.onopen[0]()
    assert.equal(opens, 1)

    socket.conn.onclose[0]()
    assert.equal(closes, 1)

    socket.conn.onerror[0]("error")
    assert.equal(lastError, "error")

    socket.conn.onmessage[0]({data: '{"topic":"topic","event":"event","payload":"message","status":"ok"}'})
    assert.equal(lastMessage, "message")
  })
})
