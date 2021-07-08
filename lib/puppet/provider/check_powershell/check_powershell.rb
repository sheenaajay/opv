# frozen_string_literal: true

require 'puppet/resource_api'
require 'puppet/resource_api/simple_provider'
require 'ruby-pwsh'
require 'retriable'
require'pry'

# Implementation for the check_powershell type using the Resource API.
class Puppet::Provider::CheckPowershell::CheckPowershell
  def get(_context)
    []
  end

  def set(context, changes); end

  def upgrade_message
    # Message used when an invalid PS version is found.
    CHECK_POWERSHELL_UPGRADE_MSG = <<-UPGRADE
    The check_powershell requires PowerShell version %{required} - current version %{current}
    To enable this resource, please install the latest version of WMF 5+ from Microsoft.
    UPGRADE

    required_version = Gem::Version.new('5.0.10586.117')
    installed_version = Gem::Version.new(Facter.value(:powershell_version))

    if installed_version >= required_version
      context.info("Satisfying powershell_version")
    else
      Puppet.warn_once(*params)
    end
  end

  def ps_manager
    unless Pwsh::Manager.windows_powershell_supported?
      upgrade_message
      debug_output = Puppet::Util::Log.level == :debug
      Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
    end
  end

  # Update the check_powershell provider to use the above attributes to execute up to retries number of times
  # with success being defined as having one of the expected_statuses
  # and the body of the response matches body_matcher while taking into account request_timeout.

  def insync?(context, _name, attribute_name, _is_hash, should_hash)
    context.debug("Checking whether #{attribute_name} is up-to-date")

    # This callback provides the exception that was raised in the current try, the try_number, the elapsed_time for all tries so far, and the time in seconds of the next_interval.
    do_this_on_each_retry = proc do |exception, try, elapsed_time, next_interval|
      context.info("#{exception.class}: '#{exception.message}' - #{try} tries in #{elapsed_time} seconds and #{next_interval} seconds until the next try.") unless exception.nil?
    end

    Retriable.retriable(tries: should_hash[:retries], max_elapsed_time: should_hash[:request_timeout], max_interval: should_hash[:max_backoff],
multiplier: should_hash[:exponential_backoff_base], on_retry: do_this_on_each_retry) do

      begin
        result     = ps_manager.execute(should_hash[:command])
        stdout     = result[:stdout]
        native_out = result[:native_stdout]
        stderr     = result[:stderr]
        exit_code  = result[:exitcode]

        unless stderr.nil?
          stderr.each { |e| Puppet.debug "STDERR: #{e.chop}" unless e.empty? }
        end

        Puppet.debug "STDERR: #{result[:errormessage]}" unless result[:errormessage].nil?

        output = Puppet::Util::Execution::ProcessOutput.new(stdout.to_s + native_out.to_s, exit_code)

        #binding.pry
      rescue Exception => exception
        #binding.pry
        puts exception.message
        puts exception.backtrace.inspect
      end
      unless should_hash[:expected_exitcode].include? output[exit_code].to_i
        raise Puppet::Error, "check_powershell exitcode check failed. The return exitcode '#{output[exit_code]}' is not matching with the expected_exitcode '#{should_hash[:expected_exitcode]}'"
      end
      context.debug("The return exitcode '#{output[exit_code]}' is matching with the expected_exitcode '#{should_hash[:expected_exitcode]}'")
      unless output[stdout].match(should_hash[:output_matcher])
        raise Puppet::Error, "check_powershell output check failed. The return output '#{output[stdout]}' is not matching output_matcher '#{should_hash[:output_matcher]}'"
      end
      context.debug("The return output '#{output[stdout]}' is matching with output_matcher '#{should_hash[:output_matcher]}'")
      context.debug("Successfully executed the command '#{should_hash[:command]}'")
      return true
    end
    false
  end
end
