require 'phantomjs'
require 'open3'

module Jasmine
  module Runners
    class PhantomJs
      def initialize(formatter, jasmine_server_url, prevent_phantom_js_auto_install, show_console_log, phantom_config_script)
        @formatter = formatter
        @jasmine_server_url = jasmine_server_url
        @prevent_phantom_js_auto_install = prevent_phantom_js_auto_install
        @show_console_log = show_console_log
        @phantom_config_script = phantom_config_script
      end

      def run
        puts "PhantomJS runner::run"
        phantom_script = File.join(File.dirname(__FILE__), 'phantom_jasmine_run.js')
        command = "#{phantom_js_path} --debug=true '#{phantom_script}' #{jasmine_server_url} #{show_console_log} '#{@phantom_config_script}'"
        puts "Command = #{command}"
        sleep 1000
        Open3.popen2e(command) do |stdin, output, wait_thread|
          puts wait_thread.pid
          output.each do |line|
            puts ">> #{line}"
            if line =~ /^jasmine_spec_result/
              line = line.sub(/^jasmine_spec_result/, '')
              raw_results = JSON.parse(line, :max_nesting => false)
              results = raw_results.map { |r| Result.new(r) }
              formatter.format(results)
            elsif line =~ /^jasmine_suite_result/
              line = line.sub(/^jasmine_suite_result/, '')
              raw_results = JSON.parse(line, :max_nesting => false)
              results = raw_results.map { |r| Result.new(r) }
              failures = results.select(&:failed?)
              if failures.any?
                formatter.format(failures)
              end
            elsif line =~ /^Failed to configure phantom$/
              config_failure = Result.new('fullName' => line,
                                          'failedExpectations' => [],
                                          'description' => '',
                                          'status' => 'failed')
              formatter.format([config_failure])
              @show_console_log = true
              puts line
            elsif show_console_log
              puts line
            end
          end
          puts "Exit code: #{wait_thread.value}"
        end
        formatter.done
      end

      def phantom_js_path
        prevent_phantom_js_auto_install ? 'phantomjs' : Phantomjs.path
      end

      def boot_js
        File.expand_path('phantom_boot.js', File.dirname(__FILE__))
      end

      private
      attr_reader :formatter, :jasmine_server_url, :prevent_phantom_js_auto_install, :show_console_log
    end
  end
end

