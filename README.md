![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/phoenix.png)
> ### Productive. Reliable. Fast.
> A productive web framework that does not compromise speed and maintainability.

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

## Getting started

See the official site at http://www.phoenixframework.org/

## Documentation

API documentation is available at [http://hexdocs.pm/phoenix](http://hexdocs.pm/phoenix)

## Contributing

We appreciate any contribution to Phoenix. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs [in the issue tracker][2].

### Running a Phoenix master app

```bash
$ cd installer
$ mix phoenix.new path/to/your/app --dev
```

The command above will create a new application, using your current Phoenix checkout thanks to the `--dev` flag.

### Building phoenix.js

```bash
$ npm install
$ npm install -g brunch
$ brunch watch
```

### Building docs from source

```bash
$ MIX_ENV=docs mix docs
```

## Important links

* \#elixir-lang on freenode IRC
* [elixir-lang slack channel][1]
* [Issue tracker][2]
* [phoenix-talk Mailing list (questions)][3]
* [phoenix-core Mailing list (development)][4]

  [1]: https://elixir-slackin.herokuapp.com/
  [2]: https://github.com/phoenixframework/phoenix/issues
  [3]: http://groups.google.com/group/phoenix-talk
  [4]: http://groups.google.com/group/phoenix-core
