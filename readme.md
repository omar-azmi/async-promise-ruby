# async-promise


## Overview

This library provides Javascript-like promises to Ruby.
It allows you to create and manage asynchronous operations with ease, providing a familiar API for those who have worked with JavaScript promises.

This library provides a Ruby implementation of ES6-like JavaScript Promises.
It allows one to build asynchronous logic with ease, in addition to being able to handle exceptions.
Under the hood, this library uses the [async](https://github.com/socketry/async) gem for concurrency management.


## Installation

Install the gem via `bundler` by executing:

```shell
bundle add async-promise
```


## Examples

### Example 1: Basic promise resolution

Here's how to create a new promise and resolve it with the value `"Success!"`.
By calling the `then` method on our `promise`, we get to hook additional tasks that should be carried out after the `promise` is settled.
The first lambda argument in the `then` method specifies the action to take if `promise` was resolved successfully.
The second lambda argument specifies the action to take if the `promise` was rejected.

```rb
require "async"
require "async/promise"

Async do
  promise = Async::Promise.new()

  promise
    .then(->(value) { puts "Resolved with: #{value}" }) # callback for success
    .catch(->(reason) { puts "Error: #{reason}" })      # callback for failure

  promise.resolve("Success!")
  # console output:
  # Resolved with: Success!
end
```

### Example 2: Chaining promises

This example demonstrates how to chain multiple `then` calls, passing the resolved value along the chain.

```rb
require "async"
require "async/promise"

Async do
  promise = Async::Promise.new()

  promise
    .then(->(value) { return "#{value} World" }) # Modify the value
    .then(->(value) { return "#{value}!" })      # Further modify the value
    .then(->(value) { puts value })              # Output the final value

  promise.resolve("Hello")
  # console output:
  # Hello World!
end
```

### Example 3: Handling rejections

This example demonstrates how to handle promise rejections by using the `catch` method, or using the second argument of the `then` method.

```rb
require "async"
require "async/promise"

Async do
  promise1 = Async::Promise.new()

  promise2 = promise1
    .then(->(value) { puts "Resolved with: #{value}" }) # This won't be called
    .catch(->(reason) {
      puts "Caught error: #{reason}"
      raise "Error when catching error!?"
    }) # Error handling in addition to throwing another error, which is caught in the next `then` promise.
    .then(
      nil,
      ->(reason) {
        puts "Caught yet another error: #{reason}"
        return "hEy b0ss!"
      }
    )

  promise1.reject("Something went wrong!")
  # console output:
  # Caught error: Something went wrong!
  # Caught yet another error: Error when catching error!?

  puts promise2.wait # wait for the promise to get its resolved value
  # console output:
  # hEy b0ss!

  # waiting for a rejected promise will raise an error
  begin puts promise1.wait # an error will be raised here
  rescue => error; puts error.message
  end
  # console output:
  # Something went wrong!
end
```

## Usage

Check out the type annotations and YARD doc comments in the [`./sig/async/promise.rbs`](./sig/async/promise.rbs) file.
Otherwise, a summary follows:

### Promise methods
- `#status()`: Returns the current status of the promise: "pending", "fulfilled", or "rejected".
- `#resolve(value)`: Fulfills the promise with the given `value`.
- `#reject(reason)`: Rejects the promise with the provided `reason`.
- `#then(on_resolve, on_reject)`: Chains asynchronous operations and provides handlers for resolution and rejection.
- `#catch(on_reject)`: Catches errors that occurred in preceding promise chains.
- `#wait`: Blocks the current execution until the promise is settled and returns the resolved value or raises an error if rejected.

### Promise class methods
- `.resolve(value)`: Creates a pre-resolved promise.
- `.reject(reason)`: Creates a pre-rejected promise.
- `.all(promises)`: Returns a promise that resolves when all input promises are resolved or rejects when any one of them is rejected.
- `.race(promises)`: Returns a promise that settles as soon as any input promise is settled (either fulfilled or rejected).
- `.timeout(resolve_in, reject_in, resolve, reject)`: Returns a promise that settles after a specified timeout, either resolving or rejecting.


## Contributing

Bug reports and pull requests are welcome on GitHub at: [https://github.com/omar-azmi/async-promise-ruby](https://github.com/omar-azmi/async-promise-ruby).


## Development

Clone the repo

```shell
git clone https://github.com/omar-azmi/async-promise-ruby.git
```

Install dependencies

```shell
bundle install
```

Run tests (in parallel)

```shell
bundle exec sus-parallel
```

Make changes to the source code and increment the library version.

Build the gem library file

```shell
gem build "./async-promise.gemspec"
```

Push the changes to [rubygems.org](https://rubygems.org)

```shell
gem push "./async-promise-*.gem"
```
