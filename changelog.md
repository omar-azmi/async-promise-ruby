## [Unreleased]


## [0.1.0] - 2024-10-03

### Summary
- Initial release

### Added
- Ability to create Javascript ES6 like [promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) via the `Async::Promise` class.
- Add the following `Promise` instance methods:
  - `#status(): "pending" | "fulfilled" | "rejected"`
    - get the status of a promise, which can either be `"pending"`, `"fulfilled"`, or `"rejected"`.
    - when a promise is either `"fulfilled"` or `"rejected"`, we say that it has been *settled*.
  - `#resolve(value?: T): void`
    - resolve a `"pending"` promise with the given `value`, and set the `#status` of the promise to `"fulfilled"`.
    - an already settled promise cannot be resolved nor rejected again.
  - `#reject(reason?: String | StandardException): void`
    - reject a `"pending"` promise with the given `reason`, and set the `#status` of the promise to `"rejected"`.
    - an already settled promise cannot be resolved nor rejected again.
  - `#then(on_resolve?: nil | ((value: T) => (V | Promise<V>)), on_reject?: nil | ((reason: String | StandardException) => (V | Promise<V>))): Promise<V>`
    - chain the current promise with an `on_resolve` and an `on_reject` function, which shall be called when the current promise is resolved.
    - the returned value is another promise, that is resolved once either the `on_resolve` or `on_reject` are ran successfully.
    - when either the `on_resolve` or `on_reject` functions are `nil`, the supposed `value`/`reason` they are to receive will be passed onto the dependent promises of the returned promise.
      in a way, it will behave as if `on_resolve = ->(value) { return value }` and `on_reject = ->(reason) { raise reason }`.
  - `#catch(on_reject?: nil | ((reason: String | StandardException) => (V | Promise<V>)))`
    - catch any raised exceptions that have occurred in preceding chain of promises.
    - this is functionally equivalent to `some_promise.then(nil, ->(reason){ "take care of the error" })`
  - `#wait(): T`
    - wait for a promise to settle, similar to how one can await a promise in javascript via `await some_promise`.
    - the returned value will be the resolved value of the promise (i.e. when the status is `"fulfilled"`), or it will raise an error if the promise was rejected (i.e. when the status is `"rejected"`).
- Add the following `Promise` class methods:
  - `.resolve(value?: T): Promise<T>`
    - creates an already resolved promise.
  - `.reject(reason?: String | StandardException): Promise<T>`
    - creates an already rejected promise.
  - `.all(promises: Array<Promise<T>>): Promise<Array<T>>`
    - create a new promise that resolves when all of its input promises have been resolved, and rejects when any single input promise is rejected.
  - `.race(promises: Array<Promise<T>>): Promise<T>`
    - create a new promise that either rejects or resolves based on whichever encompassing promise settles first.
  - `.timeout(resolve_in: Float, reject_in: Float, resolve: T, reject: String, StandardError): Promise<T>`
    - create a promise that either resolves or rejects after a given timeout.

### Dependency
- Add dependency on the [async](https://github.com/socketry/async) gem.
  More specifically, the library depends on the following two constructs of the said gem:
  - `Async` Kernel block
  - `Async::Variable` Class
