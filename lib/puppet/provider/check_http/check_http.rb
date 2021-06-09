# frozen_string_literal: true

require 'puppet/resource_api'
require 'puppet/resource_api/simple_provider'
require 'net/http'
require 'retriable'

# Implementation for the check_http type using the Resource API.
class Puppet::Provider::CheckHttp::CheckHttp
  def get(_context)
    []
  end

  def set(context, changes)
  end

  # Update the check_http provider to use the above attributes to execute up to retries number of times
  # with success being defined as having one of the expected_statuses
  # and the body of the response matches body_matcher while taking into account request_timeout.

  def insync?(context, name, attribute_name, is_hash, should_hash)
    context.debug("Checking whether #{attribute_name} is up-to-date")
    uri = URI(should_hash[:url])

    # Update the check_http provider to wait for backoff ** (exponential_backoff_base * (retries - 1) seconds between attempts (up to max_backoff)
    base_interval = should_hash[:backoff] ** (should_hash[:exponential_backoff_base] * should_hash[:retries] - 1)

    # This callback provides the exception that was raised in the current try, the try_number, the elapsed_time for all tries so far, and the time in seconds of the next_interval.
    do_this_on_each_retry = Proc.new do |exception, try, elapsed_time, next_interval|
      context.info("#{exception.class}: '#{exception.message}' - #{try} tries in #{elapsed_time} seconds and #{next_interval} seconds until the next try.")
    end

    context.processing(uri.to_s, {}, {}, message: 'checking http') do
      base_interval = 0
      retried = 0
      Retriable.retriable(tries: should_hash[:retries], max_elapsed_time: should_hash[:request_timeout], base_interval: base_interval, max_interval: should_hash[:max_backoff], multiplier: should_hash[:exponential_backoff_base], on_retry: do_this_on_each_retry) do
        retried +=1

        # Update the check_http provider to wait for backoff ** (exponential_backoff_base * (retries - 1) seconds between attempts (up to max_backoff)
        base_interval = should_hash[:backoff] ** should_hash[:exponential_backoff_base] * (retried - 1)
        context.info("The base_interval is '#{base_interval}' and retrying for '#{retried}' time")

        response = Net::HTTP.get_response(uri)

        # Success being defined as having one of the expected_statuses and the body of the response matches body_matcher
        if (should_hash[:expected_statuses].include? response.code.to_i)
          context.info("The return response '#{response.code}' is matching with the expected_statuses '#{should_hash[:expected_statuses]}'")
          if (response.body.match(should_hash[:body_matcher]))
            context.info("The return response body '#{response.body[0..99]}' is matching with body_matcher '#{should_hash[:body_matcher]}.to_s'")
          else
            raise Puppet::Error, "check_http response body check failed. The return response body '#{response.body[0..99]}' is not matching body_matcher '#{should_hash[:body_matcher]}.to_s'"
          end
          context.info("Successfully connected to '#{name}'")
          return true
        else
          raise Puppet::Error, "check_http response code check failed. The return response '#{response.code}' is not matching with the expected_statuses '#{should_hash[:expected_statuses]}.to_s'"
        end
      end
      return false
    end
  end
end
