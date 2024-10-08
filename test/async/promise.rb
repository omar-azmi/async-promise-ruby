# frozen_string_literal: true

require "sus"
require "time"
require "./lib/async/promise"

describe Async::Promise do
	Promise = Async::Promise

	### Testing for Synchronous behavior, to verify control flow
	with "Synchronous Resolution Behavior" do
		it "should resolve with a value" do
			final_value = nil
			Async do
				p1 = Promise.new
				p2 = p1.then(->(v) { final_value = v; v })
				p1.resolve("Success")
				expect(final_value).to be == "Success"
				expect(p2.wait).to be == "Success"
				expect(p1.wait).to be == "Success"
			end
		end

		it "should chain multiple thens and propagate resolved values" do
			final_value = nil
			Async do
				p1 = Promise.new
				p2 = p1
					.then(->(v) { "#{v} World" })
					.then(->(v) { "#{v}!" })
					.then(->(v) { final_value = v; v })
				p1.resolve("Hello")
				expect(p2.wait).to be == "Hello World!"
			end
			expect(final_value).to be == "Hello World!"
		end

		it "should resolve immediately for latecomer then calls after promise is resolved" do
			final_value = nil
			Async do
				p = Promise.new
				p.resolve("Already Resolved")
				expect(p.then(->(v) { final_value = v }).wait).to be == "Already Resolved"
			end
			expect(final_value).to be == "Already Resolved"
		end

		it "should handle promise returned in then block" do
			final_value = nil
			Async do
				promise = Promise.new
				inner_promise = Promise.new
				promise
					.then(->(_) { inner_promise })
					.then(->(v) { final_value = v })

				promise.resolve("Outer Resolved")
				expect(final_value).to be_nil() # because `inner_promise` has not been resolved yet
				inner_promise.resolve("Inner Resolved")
				expect(inner_promise.wait).to be == "Inner Resolved"
			end
			expect(final_value).to be == "Inner Resolved"
		end
	end

	with "Synchronous Rejection Behavior" do
		it "should reject with an error" do
			reason = nil
			Async do
				p1 = Promise.new
				p2 = p1.catch(->(e) { reason = e; nil })
				p1.reject("Rejected!")
				expect(p2.wait).to be_nil()
			end
			expect(reason).to be == "Rejected!"
		end

		it "should reject immediately for latecomer then calls, after the promise has already been rejected" do
			reason = nil
			Async do
				p1 = Promise.new
				p1.reject("Already Rejected!")
				expect { p1.wait }.to raise_exception(StandardError, message: be == "Already Rejected!")
				p2 = p1.catch(->(e) { reason = e; nil })
				expect(reason).to be == "Already Rejected!" # the new value should get assigned even before we wait for p2, because its dependency, p1, has already completed execution (rejected)
				expect(p2.wait).to be_nil()
				expect { p1.wait }.to raise_exception(StandardError, message: be == "Already Rejected!") # waiting for a failed promise again should raise the error again.
			end
			expect(reason).to be == "Already Rejected!"
		end

		it "should propagate rejection through then chains" do
			reason = nil
			Async do
				p1 = Promise.new
				p2 = p1
					.then(->(v) { "#{v} World" })
					.catch(->(e) { reason = e; nil })
				p1.reject("Error occurred")
				expect(p2.wait).to be_nil()
			end
			expect(reason).to be == "Error occurred"
		end

		it "should propagate error originating inside of the promise chain, through the upcoming chained promises" do
			reason = nil
			Async do
				p1 = Promise.new
				p2 = p1
					.then(->(_) { raise "Another Error" })
					.catch(->(e) { reason = e; nil })
				p1.resolve("Initial")
				expect(p2.wait).to be_nil()
			end
			expect(reason.message).to be == "Another Error"
		end

		it "should recover from rejection in catch and propagate resolved value" do
			final_value = nil
			Async do
				p1 = Promise.new
				p2 = p1
					.then(->(v) { raise "Failure" })
					.catch(->(e) { "Recovered" })
					.then(->(v) { final_value = v; v })
				p1.resolve("Initial Value")
				expect(p2.wait).to be == "Recovered"
			end
			expect(final_value).to be == "Recovered"
		end
	end

	with "Edge Cases" do
		it "should not allow resolution after rejection" do
			value = nil
			reason = nil
			Async do
				p1 = Promise.new
				p2 = p1.then(->(v) { value = v; v }, ->(e) { reason = e; e })
				p1.reject("First Rejection")
				p1.resolve("Attempt to resolve after rejection")
				expect(p2.wait).to be == "First Rejection"
			end
			expect(value).to be_nil()
			expect(reason).to be == "First Rejection"
		end

		it "should not allow rejection after resolution" do
			value = nil
			reason = nil
			Async do
				p1 = Promise.new
				p2 = p1.then(->(v) { value = v; v }, ->(e) { reason = e; e })
				p1.resolve("First Resolution")
				p1.reject("Attempt to reject after resolution")
				expect(p2.wait).to be == "First Resolution"
			end
			expect(value).to be == "First Resolution"
			expect(reason).to be_nil()
		end

		it "should throw error for unhandled rejections when they are waited for" do
			Async do
				p = Promise.new
				p.reject("Unhandled Rejection")
				# the error gets risen only after we call the wait method
				expect { p.wait }.to raise_exception(StandardError, message: be == "Unhandled Rejection")
			end
		end
	end


	### Testing static methods of the class
	with "Static Methods" do
		describe "Promise.resolve" do
			it "creates a promise that resolves immediately with a given value" do
				result = nil
				Async do
					p = Promise.resolve("Resolved Value")
					p.then(->(v) { result = v }).wait
				end
				expect(result).to be == "Resolved Value"
			end

			it "handles a resolved Promise passed into .resolve" do
				result = nil
				Async do
					inner_promise = Promise.resolve("Inner Resolved")
					promise = Promise.resolve(inner_promise)
					promise.then(->(v) { result = v }).wait
				end
				expect(result).to be == "Inner Resolved"
			end

			it "handles a nil value in .resolve" do
				result = "not_nil"
				Async do
					p = Promise.resolve(nil)
					p.then(->(v) { result = v }).wait
				end
				expect(result).to be_nil
			end
		end

		describe "Promise.reject" do
			it "creates a promise that rejects immediately with a given reason" do
				rejection_reason = nil
				Async do
					p = Promise.reject("Rejection Reason")
					p.catch(->(e) { rejection_reason = e }).wait
				end
				expect(rejection_reason).to be == "Rejection Reason"
			end

			it "handles rejection of an Promise in .reject" do
				rejection_reason = nil
				Async do
					p = Promise.reject(StandardError.new("Error occurred"))
					p.catch(->(e) { rejection_reason = e.message }).wait
				end
				expect(rejection_reason).to be == "Error occurred"
			end
		end

		describe "Promise.all" do
			it "resolves when all promises resolve, and maintains the order of the promises" do
				Async do
					# Resolve all promises in different orders
					p1 = Promise.resolve("Value 1").then(->(v) { sleep 0.3; v })
					p2 = Promise.resolve("Value 2").then(->(v) { sleep 0.1; v })
					p3 = Promise.resolve("Value 3").then(->(v) { sleep 0.2; v })
					p4 = Promise.all([ p1, p2, p3 ])
					expect(p4.wait).to be == [ "Value 1", "Value 2", "Value 3" ]
				end
			end

			it "rejects if any promise rejects" do
				rejection_reason = nil
				Async do
					# Resolve two, reject one
					p1 = Promise.resolve("Value 1").then(->(v) { sleep 0.1; v })
					p2 = Promise.reject("Rejection Reason").catch(->(e) { sleep 0.3; raise e })
					p3 = Promise.resolve("Value 3").then(->(v) { sleep 0.2; v })
					p4 = Promise.all([ p1, p2, p3 ]).catch(->(reason) { rejection_reason = reason.message; raise reason })
					expect { p4.wait }.to raise_exception(StandardError, message: be == "Rejection Reason")
				end
				expect(rejection_reason).to be == "Rejection Reason"
			end

			it "handles an empty array of promises and resolves immediately" do
				result = nil
				Async do
					p1 = Promise.all([])
					p2 = p1.then(->(values) { result = values })
					expect(result).to be == [] # the value should be resolved even before we begin to wait
					expect(p2.wait).to be == []
				end
			end

			it "handles a mixture of regular non-promise values and actual promises" do
				Async do
					p1 = Promise.resolve("Value 1").then(->(v) { sleep 0.3; v })
					p2 = Promise.resolve("Value 2").then(->(v) { sleep 0.1; v })
					v3 = "Value 3"
					p4 = Promise.all([ p1, p2, v3 ])
					expect(p4.wait).to be == [ "Value 1", "Value 2", "Value 3" ]
				end
			end

			it "handles already resolved promises in .all" do
				result = nil
				Async do
					p1 = Promise.resolve("Resolved 1")
					p2 = Promise.resolve("Resolved 2")
					p3 = Promise.resolve("Resolved 3")
					p4 = Promise.all([ p1, p2, p3 ]).then(->(values) { result = values })
					expect(result).to be == [ "Resolved 1", "Resolved 2", "Resolved 3" ] # the value should be resolved even before we begin to wait
					expect(p4.wait).to be == [ "Resolved 1", "Resolved 2", "Resolved 3" ]
				end
			end

			it "immediately rejects if any of the promises are already rejected" do
				rejection_reason = nil
				Async do
					p1 = Promise.resolve("Resolved 1")
					p2 = Promise.reject("Immediate Rejection")
					p3 = Promise.resolve("Resolved 3")
					p4 = Promise.all([ p1, p2, p3 ]).catch(->(reason) { rejection_reason = reason; raise reason })
					expect(rejection_reason).to be == "Immediate Rejection" # the value should be rejected, even before we begin to wait
					expect { p4.wait }.to raise_exception(StandardError, message: be == "Immediate Rejection")
				end
			end
		end

		describe "Promise.race" do
			it "resolves with the first resolved promise in the race" do
				delta_time = Time.now
				Async do
					p1 = Promise.resolve("First resolved late").then(->(v) { sleep 0.5; v })
					p2 = Promise.resolve("Second won").then(->(v) { sleep 0.2; v })
					p3 = Promise.reject("Third failed later").catch(->(e) { sleep 0.7; e })
					p4 = Promise.race([ p1, p2, p3 ])
					expect(p4.wait).to be == "Second won"
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.2 .. 0.4)
				end
			end

			it "rejects with the first rejected promise in the race" do
				delta_time = Time.now
				Async do
					p1 = Promise.resolve("First won very late").then(->(v) { sleep 0.7; v })
					p2 = Promise.resolve("Second won later").then(->(v) { sleep 0.5; v })
					p3 = Promise.reject("Third failed first").catch(->(e) { sleep 0.2; raise e })
					p4 = Promise.race([ p1, p2, p3 ])
					expect { p4.wait }.to raise_exception(StandardError, message: be == "Third failed first")
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.2 .. 0.4)
				end
			end

			it "immediately resolves if a non-promise object is passed, even if there exists resolved promises prior to it" do
				delta_time = Time.now
				result = nil
				Async do
					p1 = Promise.resolve("Resolved instantly")
					p2 = Promise.reject("Rejected instantly")
					p3 = Promise.resolve("Resolved later").then(->(v) { sleep 0.3; v })
					v4 = "Not a Promise"
					v5 = "A Second Non-Promise"
					p6 = Promise.resolve("Resolved later").then(->(v) { sleep 0.5; v })
					p7 = Promise.race([ p1, p2, p3, v4, v5, p6 ]).then(->(v) { result = v; v })
					expect(result).to be == "Not a Promise" # the result is resolved even before we wait for the promise, because a non-promise promise was passed
					expect(p7.wait).to be == "Not a Promise"
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.0 .. 0.2)
				end
			end

			it "immediately resolves if a pre-resolved promise is passed" do
				delta_time = Time.now
				result = nil
				Async do
					p1 = Promise.resolve("Resolved instantly")
					p2 = Promise.resolve("Resolved later").then(->(v) { sleep 0.3; v })
					p3 = Promise.race([ p1, p2 ]).then(->(v) { result = v; v })
					expect(result).to be == "Resolved instantly" # the result is resolved even before we wait for the promise, because a pre-resolved promise was passed
					expect(p3.wait).to be == "Resolved instantly"
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.0 .. 0.2)
				end
			end

			it "immediately rejects if a pre-rejected promise is passed" do
				delta_time = Time.now
				rejection_reason = nil
				result = nil
				Async do
					p1 = Promise.reject("Rejected instantly")
					p2 = Promise.resolve("Resolved later").then(->(v) { sleep 0.3; v })
					p3 = Promise.race([ p1, p2 ]).then(->(v) { result = v; v }, ->(e) { rejection_reason = e; raise e })
					expect(rejection_reason).to be == "Rejected instantly" # the result is rejected even before we wait for the promise, because a pre-resolved promise was passed
					expect { p3.wait }.to raise_exception(StandardError, message: be == "Rejected instantly")
					expect(result).to be_nil()
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.0 .. 0.2)
				end
			end
		end

		describe "Promise.timeout" do
			it "resolves after the specified resolve_in timeout" do
				delta_time = Time.now
				Async do
					expect(Promise.timeout(0.2, resolve: "Resolved after timeout").wait).to be == "Resolved after timeout"
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.2 .. 0.4)
				end
			end

			it "rejects after the specified reject_in timeout" do
				delta_time = Time.now
				Async do
					expect { Promise.timeout(nil, 0.2, reject: "Rejected after timeout").wait }.to raise_exception(StandardError, message: be == "Rejected after timeout")
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.2 .. 0.4)
				end
			end

			it "resolves if `resolve_in` is shorter than `reject_in`" do
				delta_time = Time.now
				Async do
					expect(Promise.timeout(0.2, 0.5, resolve: "Resolved first", reject: "Rejected second").wait).to be == "Resolved first"
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.2 .. 0.4)
				end
			end

			it "rejects if reject_in is shorter than resolve_in" do
				delta_time = Time.now
				Async do
					expect { Promise.timeout(0.5, 0.2, resolve: "Resolved second", reject: "Rejected first").wait }.to raise_exception(StandardError, message: be == "Rejected first")
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.2 .. 0.4)
				end
			end

			it "resolves immediately if resolve_in is zero" do
				delta_time = Time.now
				Async do
					expect(Promise.timeout(0, resolve: "Resolved instantly").wait).to be == "Resolved instantly"
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.0 .. 0.1)
				end
			end

			it "rejects immediately if reject_in is zero" do
				delta_time = Time.now
				Async do
					expect { Promise.timeout(nil, 0, reject: "Rejected instantly").wait }.to raise_exception(StandardError, message: be == "Rejected instantly")
					delta_time = Time.now - delta_time
					expect(delta_time).to be_within(0.0 .. 0.1)
				end
			end

			it "does nothing if neither `resolve_in` nor `reject_in` times are provided (hanging promise)." do
				delta_time = Time.now
				Async do
					p = Promise.timeout()
					sleep 0.5
					delta_time = Time.now - delta_time
					expect(p.status()).to be == "pending"
					p.resolve("End the cycle of hanging misery")
					expect(p.wait).to be == "End the cycle of hanging misery"
				end
				expect(delta_time).to be_within(0.5 .. 0.7)
			end
		end
	end


	### Testing for Asynchronous behavior
	with "Asynchronous Behavior" do
		it "should resolve two independent promises concurrently" do
			delta_time = Time.now

			Async do
				p1 = Promise.new
				p2 = Promise.new

				Async do
					sleep 1  # Simulates a long-running task
					p1.resolve("Promise 1 Resolved")
				end
				Async do
					sleep 0.5  # Simulates a shorter task
					p2.resolve("Promise 2 Resolved")
				end

				# Waiting for both promises to resolve
				expect(p1.wait).to be == "Promise 1 Resolved"
				expect(p2.wait).to be == "Promise 2 Resolved"
				delta_time = Time.now - delta_time
			end
			# Both promises should resolve concurrently, so the total time should be about 1 second
			expect(delta_time).to be_within(1.0 .. 1.2)
		end

		it "should resolve two independent promises concurrently within the `on_resolve` lambda" do
			delta_time = Time.now

			Async do
				p1 = Promise.new(->(v) {
					sleep 1  # Simulates a long-running task
					v
				})
				p2 = Promise.new(->(v) {
					sleep 0.5  # Simulates a shorter task
					v
				})

				p1.resolve("Promise 1 Resolved")
				p2.resolve("Promise 2 Resolved")

				# Waiting for both promises to resolve
				expect(p1.wait).to be == "Promise 1 Resolved"
				expect(p2.wait).to be == "Promise 2 Resolved"
				delta_time = Time.now - delta_time
			end
			# Both promises should resolve concurrently, so the total time should be about 1 second
			expect(delta_time).to be_within(1.0 .. 1.2)
		end

		it "should resolve promises in a chain sequentially" do
			delta_time = Time.now
			final_value = nil

			Async do
				p1 = Promise.new
				p2 = p1
					.then(->(v) { sleep 0.5; "#{v} -> Step 1" })
					.then(->(v) { sleep 0.5; "#{v} -> Step 2" })
					.then(->(v) { final_value = v; v })

				Async do
					sleep 0.5
					p1.resolve("Step 0")
				end

				expect(p2.wait).to be == "Step 0 -> Step 1 -> Step 2"
				expect(final_value).to be == "Step 0 -> Step 1 -> Step 2"
				delta_time = Time.now - delta_time
			end
			# The total time should be 1.5 seconds (0.5 + 0.5 + 0.5) because we waited for the last promise in the chain
			expect(delta_time).to be_within(1.5 .. 1.7)
		end

		it "should exit an async block early, even if there are pending (and un-awaited) chained promises" do
			delta_time = Time.now
			final_value = nil

			Async do
				p = Promise.new
				p
					.then(->(v) { sleep 0.5; "#{v} -> Step 1" })
					.then(->(v) { sleep 0.5; "#{v} -> Step 2" })
					.then(->(v) { final_value = v; v })

				Async do
					sleep 0.5
					p.resolve("Step 0")
				end

				expect(p.wait).to be == "Step 0" # since only `p` is awaited for, and not the chained promises, we should exit early at 0.5 seconds
				expect(final_value).to be_nil()
				delta_time = Time.now - delta_time
			end
			# The total time should be 0.5 seconds, since the children/chained promises are not awaited for
			expect(delta_time).to be_within(0.5 .. 0.7)
		end

		it "should run two separate promise chains concurrently" do
			delta_time = Time.now
			final_value_1 = nil
			final_value_2 = nil

			Async do
				# Two independent promise chains
				promise_a = Promise.new(->(v) { sleep 0.5; v })
				promise_b = Promise.new(->(v) { sleep 0.7; v })

				p1 = promise_a
					.then(->(v) { sleep 0.5; "#{v} -> Step 1 (chain 1)" })
					.then(->(v) { final_value_1 = v; v })
				p2 = promise_b
					.then(->(v) { sleep 0.7; "#{v} -> Step 1 (chain 2)" })
					.then(->(v) { final_value_2 = v; v })

				promise_a.resolve("Start Chain 1")
				promise_b.resolve("Start Chain 2")

				# Wait for both promise chains to finish
				expect(p1.wait).to be == "Start Chain 1 -> Step 1 (chain 1)"
				expect(final_value_1).to be == "Start Chain 1 -> Step 1 (chain 1)"
				expect(final_value_2).to be_nil()
				expect(Time.now - delta_time).to be_within(1.0 .. 1.2)
				expect(p2.wait).to be == "Start Chain 2 -> Step 1 (chain 2)"
				expect(final_value_2).to be == "Start Chain 2 -> Step 1 (chain 2)"
				expect(Time.now - delta_time).to be_within(1.4 .. 1.6)
				delta_time = Time.now - delta_time
			end
			# The total time should be about 1.4 seconds since both promises run concurrently, but the slowest chain takes 1.4 seconds
			expect(delta_time).to be_within(1.4 .. 1.6)
		end

		it "should run two separate promise chains concurrently, and should wait for zero seconds for an already resolved promise chain" do
			# This example is exactly like the previous one, except that we `wait` for the chains in opposite order (slower first, faster one second)
			delta_time = Time.now
			final_value_1 = nil
			final_value_2 = nil

			Async do
				# Two independent promise chains
				promise_a = Promise.new(->(v) { sleep 0.5; v })
				promise_b = Promise.new(->(v) { sleep 0.7; v })

				p1 = promise_a
					.then(->(v) { sleep 0.5; "#{v} -> Step 1 (chain 1)" })
					.then(->(v) { final_value_1 = v; v })
				p2 = promise_b
					.then(->(v) { sleep 0.7; "#{v} -> Step 1 (chain 2)" })
					.then(->(v) { final_value_2 = v; v })

				promise_a.resolve("Start Chain 1")
				promise_b.resolve("Start Chain 2")

				# Wait for both promise chains to finish (wait for the slower one first, and then the faster one should be resolved in zero time delay)
				expect(p2.wait).to be == "Start Chain 2 -> Step 1 (chain 2)"
				expect(final_value_2).to be == "Start Chain 2 -> Step 1 (chain 2)"
				expect(final_value_1).to be == "Start Chain 1 -> Step 1 (chain 1)" # although `p1` was not awaited, it should be resolved by this time.
				expect(Time.now - delta_time).to be_within(1.4 .. 1.6)
				expect(p1.wait).to be == "Start Chain 1 -> Step 1 (chain 1)"
				expect(final_value_1).to be == "Start Chain 1 -> Step 1 (chain 1)"
				expect(Time.now - delta_time).to be_within(1.4 .. 1.6)
				delta_time = Time.now - delta_time
			end
			# The total time should be about 1.4 seconds since both promises run concurrently, but the slowest chain takes 1.4 seconds
			expect(delta_time).to be_within(1.4 .. 1.6)
		end

		it "should handle promise rejection via the `catch` method, asynchronously" do
			delta_time = Time.now
			final_value = nil
			rejection_reason = nil

			Async do
				p1 = Promise.new(->(v) { sleep 0.3; v })
				p2 = p1
					.then(->(v) { sleep 0.5; raise "Step 1 failed" })
					.catch(->(e) { rejection_reason = e.message; "Recovered" })
					.then(->(v) { final_value = v; v })

				p1.resolve("Start Chain")
				expect(p2.wait).to be == "Recovered"
				delta_time = Time.now - delta_time
			end
			# Total time should be about 0.8 seconds (0.3 + 0.5) for resolving and rejecting
			expect(delta_time).to be_within(0.8 .. 1.0)
			expect(rejection_reason).to be == "Step 1 failed"
			expect(final_value).to be == "Recovered"
		end

		it "should handle promise rejection via `then` method's `on_rejected` argument, asynchronously" do
			delta_time = Time.now
			final_value = nil
			rejection_reason = nil

			Async do
				p1 = Promise.new(->(v) { sleep 0.3; v })
				p2 = p1
					.then(->(v) { sleep 0.5; raise "Step 1 failed" })
					.then(nil, ->(e) { rejection_reason = e.message; "Recovered" })
					.then(->(v) { final_value = v; v })

				p1.resolve("Start Chain")
				expect(p2.wait).to be == "Recovered"
				delta_time = Time.now - delta_time
			end
			# Total time should be about 0.8 seconds (0.3 + 0.5) for resolving and rejecting
			expect(delta_time).to be_within(0.8 .. 1.0)
			expect(rejection_reason).to be == "Step 1 failed"
			expect(final_value).to be == "Recovered"
		end

		it "should raise an error when error is not caught by an awaited promise" do
			delta_time = Time.now
			final_value = nil

			Async do
				p1 = Promise.new(->(v) { sleep 0.3; v })
				p2 = p1
					.then(->(v) { sleep 0.5; raise "Step 1 failed" })
					.then(->(v) { final_value = v; v }, nil)

				p1.resolve("Start Chain")
				# uncaught exceptions should only be raised when the promise responsible for handling it is awaiten for.
				expect { p2.wait }.to raise_exception(StandardError, message: be == "Step 1 failed")
				delta_time = Time.now - delta_time
			end
			# Total time should be about 0.8 seconds (0.3 + 0.5) for resolving and rejecting
			expect(delta_time).to be_within(0.8 .. 1.0)
			expect(final_value).to be_nil()
		end
	end
end
