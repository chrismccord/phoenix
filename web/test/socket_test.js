import assert from "assert"

import jsdom from "jsdom"
import sinon from "sinon"
import { WebSocket, Server as WebSocketServer } from "mock-socket"

import { Socket, LongPoll } from "../static/js/phoenix"

let socket

describe("constructor", () => {
  before(() => {
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  it("sets defaults", () => {
    socket = new Socket("/socket")

    assert.equal(socket.channels.length, 0)
    assert.equal(socket.sendBuffer.length, 0)
    assert.equal(socket.ref, 0)
    assert.equal(socket.endPoint, "/socket/websocket")
    assert.deepEqual(socket.stateChangeCallbacks, {open: [], close: [], error: [], message: []})
    assert.equal(socket.transport, LongPoll)
    assert.equal(socket.timeout, 10000)
    assert.equal(socket.longpollerTimeout, 20000)
    assert.equal(socket.heartbeatIntervalMs, 30000)
    assert.equal(typeof socket.logger, "function")
    assert.equal(typeof socket.reconnectAfterMs, "function")
  })

  it("overrides some defaults with options", () => {
    const customTransport = function transport() {}
    const customLogger = function logger() {}
    const customReconnect = function reconnect() {}

    socket = new Socket("/socket", {
      timeout: 40000,
      longpollerTimeout: 50000,
      heartbeatIntervalMs: 60000,
      transport: customTransport,
      logger: customLogger,
      reconnectAfterMs: customReconnect,
      params: { one: "two" },
    })

    assert.equal(socket.timeout, 40000)
    assert.equal(socket.longpollerTimeout, 50000)
    assert.equal(socket.heartbeatIntervalMs, 60000)
    assert.equal(socket.transport, customTransport)
    assert.equal(socket.logger, customLogger)
    assert.equal(socket.reconnectAfterMs, customReconnect)
    assert.deepEqual(socket.params, { one: "two" })
  })

  describe("with Websocket", () => {
    let mockServer

    before(() => {
      mockServer = new WebSocketServer('wss://example.com/')
    })

    after((done) => {
      mockServer.stop(() => {
        done()
        window.WebSocket = null
      })
    })

    it("defaults to Websocket transport if available", () => {
      socket = new Socket("/socket")
      assert.equal(socket.transport, WebSocket)
    })
  })
})

describe("protocol", () => {
  beforeEach(() => {
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
    mockServer = new WebSocketServer('wss://example.com/')
    jsdom.changeURL(window, "http://example.com/");
  })

  after((done) => {
    mockServer.stop(() => {
      done()
      window.WebSocket = null
    })
  })

  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("establishes websocket connection with endpoint", () => {
    socket.connect()

    let conn = socket.conn
    assert.ok(conn instanceof WebSocket)
    assert.equal(conn.url, socket.endPointURL())
  })

  it("sets callbacks for connection", () => {
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

    const data = {"topic":"topic","event":"event","payload":"payload","status":"ok"}
    socket.conn.onmessage[0]({data: JSON.stringify(data)})
    assert.equal(lastMessage, "payload")
  })

  it("is idempotent", () => {
    socket.connect()

    let conn = socket.conn

    socket.connect()

    assert.deepStrictEqual(conn, socket.conn)
  })
})

describe("connect with long poll", () => {
  before(() => {
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("establishes long poll connection with endpoint", () => {
    socket.connect()

    let conn = socket.conn
    assert.ok(conn instanceof LongPoll)
    assert.equal(conn.pollEndpoint, "http://example.com/socket/longpoll?vsn=1.0.0")
    assert.equal(conn.timeout, 20000)
  })

  it("sets callbacks for connection", () => {
    let opens = 0
    socket.onOpen(() => ++opens)
    let closes = 0
    socket.onClose(() => ++closes)
    let lastError
    socket.onError((error) => lastError = error)
    let lastMessage
    socket.onMessage((message) => lastMessage = message.payload)

    socket.connect()

    socket.conn.onopen()
    assert.equal(opens, 1)

    socket.conn.onclose()
    assert.equal(closes, 1)

    socket.conn.onerror("error")
    assert.equal(lastError, "error")

    socket.conn.onmessage({data: '{"topic":"topic","event":"event","payload":"message","status":"ok"}'})
    assert.equal(lastMessage, "message")
  })

  it("is idempotent", () => {
    socket.connect()

    let conn = socket.conn

    socket.connect()

    assert.deepStrictEqual(conn, socket.conn)
  })
})

describe("disconnect", () => {
  let mockServer

  before(() => {
    mockServer = new WebSocketServer('wss://example.com/')
    jsdom.changeURL(window, "http://example.com/");
  })

  after((done) => {
    mockServer.stop(() => {
      done()
      window.WebSocket = null
    })
  })

  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("removes existing connection", () => {
    socket.connect()
    socket.disconnect()

    assert.equal(socket.conn, null)
  })

  it("calls callback", () => {
    let count = 0
    socket.connect()
    socket.disconnect(() => count++)

    assert.equal(count, 1)
  })

  it("calls connection close callback", () => {
    socket.connect()
    const spy = sinon.spy(socket.conn, "close")

    socket.disconnect(null, "code", "reason")

    assert(spy.calledWith("code", "reason"))
  })

  it("does not throw when no connection", () => {
    assert.doesNotThrow(() => {
      socket.disconnect()
    })
  })
})

describe("connectionState", () => {
  before(() => {
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("defaults to closed", () => {
    assert.equal(socket.connectionState(), "closed")
  })

  it("returns closed if readyState unrecognized", () => {
    socket.connect()

    socket.conn.readyState = 5678
    assert.equal(socket.connectionState(), "closed")
  })

  it("returns connecting", () => {
    socket.connect()

    socket.conn.readyState = 0
    assert.equal(socket.connectionState(), "connecting")
    assert.ok(!socket.isConnected(), "is not connected")
  })

  it("returns open", () => {
    socket.connect()

    socket.conn.readyState = 1
    assert.equal(socket.connectionState(), "open")
    assert.ok(socket.isConnected(), "is connected")
 })

  it("returns closing", () => {
    socket.connect()

    socket.conn.readyState = 2
    assert.equal(socket.connectionState(), "closing")
    assert.ok(!socket.isConnected(), "is not connected")
  })

  it("returns closed", () => {
    socket.connect()

    socket.conn.readyState = 3
    assert.equal(socket.connectionState(), "closed")
    assert.ok(!socket.isConnected(), "is not connected")
  })
})

describe("channel", () => {
  let channel

  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("returns channel with given topic and params", () => {
    channel = socket.channel("topic", { one: "two" })

    assert.deepStrictEqual(channel.socket, socket)
    assert.equal(channel.topic, "topic")
    assert.deepEqual(channel.params, { one: "two" })
  })

  it("adds channel to sockets channels list", () => {
    assert.equal(socket.channels.length, 0)

    channel = socket.channel("topic", { one: "two" })

    assert.equal(socket.channels.length, 1)

    const [foundChannel] = socket.channels
    assert.deepStrictEqual(foundChannel, channel)
  })
})

describe("remove", () => {
  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("removes given channel from channels", () => {
    const channel1 = socket.channel("topic-1")
    const channel2 = socket.channel("topic-2")

    sinon.stub(channel1, "joinRef").returns(1)
    sinon.stub(channel2, "joinRef").returns(2)

    socket.remove(channel1)

    assert.equal(socket.channels.length, 1)

    const [foundChannel] = socket.channels
    assert.deepStrictEqual(foundChannel, channel2)
  })
})

describe("push", () => {
  const data = {topic: "topic", event: "event", payload: "payload", ref: "ref"}
  const json = '{"topic":"topic","event":"event","payload":"payload","ref":"ref"}'

  before(() => {
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("sends data to connection when connected", () => {
    socket.connect()
    socket.conn.readyState = 1 // open

    const spy = sinon.spy(socket.conn, "send")

    socket.push(data)

    assert.ok(spy.calledWith(json))
  })

  it("buffers data when not connected", () => {
    socket.connect()
    socket.conn.readyState = 0 // connecting

    const spy = sinon.spy(socket.conn, "send")

    assert.equal(socket.sendBuffer.length, 0)

    socket.push(data)

    assert.ok(spy.neverCalledWith(json))
    assert.equal(socket.sendBuffer.length, 1)

    const [callback] = socket.sendBuffer
    callback()
    assert.ok(spy.calledWith(json))
  })
})

describe("makeRef", () => {
  beforeEach(() => {
    socket = new Socket("/socket")
  })

  it("returns next message ref", () => {
    assert.strictEqual(socket.ref, 0)
    assert.strictEqual(socket.makeRef(), "1")
    assert.strictEqual(socket.ref, 1)
    assert.strictEqual(socket.makeRef(), "2")
    assert.strictEqual(socket.ref, 2)
  })

  it("restarts for overflow", () => {
    socket.ref = Number.MAX_SAFE_INTEGER + 1

    assert.strictEqual(socket.makeRef(), "0")
    assert.strictEqual(socket.ref, 0)
  })
})

describe("sendHeartbeat", () => {
  before(() => {
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  beforeEach(() => {
    socket = new Socket("/socket")
    socket.connect()
  })

  it("pushes heartbeat data when connected", () => {
    socket.conn.readyState = 1 // open

    const spy = sinon.spy(socket.conn, "send")
    const data = '{"topic":"phoenix","event":"heartbeat","payload":{},"ref":"1"}'

    socket.sendHeartbeat()
    assert.ok(spy.calledWith(data))
  })

  it("no ops when not connected", () => {
    socket.conn.readyState = 0 // connecting

    const spy = sinon.spy(socket.conn, "send")
    const data = '{"topic":"phoenix","event":"heartbeat","payload":{},"ref":"1"}'

    socket.sendHeartbeat()
    assert.ok(spy.neverCalledWith(data))
  })
})

describe("flushSendBuffer", () => {
  before(() => {
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  beforeEach(() => {
    socket = new Socket("/socket")
    socket.connect()
  })

  it("calls callbacks in buffer when connected", () => {
    socket.conn.readyState = 1 // open
    const spy1 = sinon.spy()
    const spy2 = sinon.spy()
    const spy3 = sinon.spy()
    socket.sendBuffer.push(spy1)
    socket.sendBuffer.push(spy2)

    socket.flushSendBuffer()

    assert.ok(spy1.calledOnce)
    assert.ok(spy2.calledOnce)
    assert.equal(spy3.callCount, 0)
  })

  it("empties sendBuffer", () => {
    socket.conn.readyState = 1 // open
    socket.sendBuffer.push(() => {})

    socket.flushSendBuffer()

    assert.deepEqual(socket.sendBuffer.length, 0)
  })
})
