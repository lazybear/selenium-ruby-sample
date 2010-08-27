#!/usr/bin/env ruby
#    Copyright (C) 2009 Alexandre Berman, Lazybear Consulting (sashka@lazybear.net)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

require 'yaml'
require "rubygems"
require "selenium/client"
require "lib/macros"
require "lib/base_test"
require 'tlsmail'

class RubySuite
   attr_accessor :selenium, :test_name, :CONFIG, :host, :port, :base_url, :browser, :debug_mode, :suite_root, :common

   def initialize(options)
      @suite_root           = File.expand_path "#{File.dirname(__FILE__)}/.."
      # -- loading global properties from yaml
      @CONFIG               = read_yaml_file(@suite_root+"/env.yaml")
      # -- loading user-defined properties from yaml
      if File.exist?(@suite_root+"/user.env.yaml")
         YAML::load(File.read(@suite_root+"/user.env.yaml")).each_pair { |key, value|
            @CONFIG[key] = value if @CONFIG[key] != nil
         }
      end
      # -- loading common id hash
      @common               = YAML::load(File.read(@suite_root+"/lib/common.yaml"))
      @host                 = @CONFIG['selenium_host']
      @port                 = @CONFIG['selenium_port']
      @browser              = @CONFIG['browser']
      @debug_mode           = @CONFIG['debug_mode']
      @base_url             = @CONFIG['base_url']
      # -- setting env for a given test
      set_test_name(options[:test_name])
      # -- do init
      do_init
   end

   # -- utility method for reading yaml data
   def read_yaml_file(file)
      if File.exist?(file)
         return YAML::load(File.read(file))
      end
      raise "-- ERROR: file doesn't exist: " + file
   end

   # -- check connection to Selenium RC
   def check_connection
      one_wait = 5
      max_wait = 15
      request = Net::HTTP::Get.new('/selenium-server/')
      wait = 0;
      while (wait < max_wait)
          begin
              response = Net::HTTP.start(@host, @port) {|http|
                  http.request(request)
              }
              break if Net::HTTPForbidden === response
              break if Net::HTTPNotFound === response
              break if Net::HTTPSuccess === response
              # When we try to connect to a down server with an Apache proxy, 
              # we'll get Net::HTTPBadGateway and get here
          rescue Errno::ECONNREFUSED
              # When we try to connect to a down server without an Apache proxy, 
              # such as a dev instance, we'll get here
          end
          sleep one_wait;
          wait += one_wait
      end
      if (wait == max_wait)
          p("-- ERROR: couldn't connect to Selenium RC on " + @host)
          return false
      end
      return true
   end

   # -- start selenium
   def do_init
      if (!check_connection)
         clean_exit(false)
      end
      begin
         p("-- SUCCESS : Selenium RC is alive !\n")
         p("-- ENV     : " + RUBY_PLATFORM)
         p("-- BROWSER : " + @browser)
         @selenium = Selenium::Client::Driver.new \
           :host => @host,
           :port => @port,
           :browser => @browser,
           :url => @base_url,
           :timeout_in_second => 10000
         @selenium.start_new_browser_session
      rescue => e
         do_fail("ERROR: " + e.inspect)
         clean_exit(false)
      end
   end

   # -- set test_name
   def set_test_name(new_name)
      @test_name = new_name
      p "\n\n:: {BEGIN} [#{@test_name}] ++++++++++++++++++\n\n"
   end

   # -- do_fail
   def do_fail(s)
      p(s)
      raise("error")
   end
 
   # -- check the page for any abnormalities
   def check_page(page)
      # -- if error is found, it will dump first 2000 characters of the page to the screen
      raise "-- [ERROR] User name incorrect !\n\n" if /User name or password is incorrect/.match(page)
      if /An Error Occurred/.match(page)
         p ("-- Error occured, dumping partial stack trace to the screen...")
         page[0,2000].each { |s| p s } if page.length >= 2000
         raise "-- [ERROR] Exception occured !\n\n"
      end
   end

   # -- element exist: true/false ?
   def element_exist?(element)
      if !@selenium.is_element_present(element)
         return false
      end
      return true
   end

   # -- verify particular element
   def verify_element(element)
      p("-- Verifying page elements...")
      raise "-- [ERROR] not able to verify element: #{element}" if !element_exist?(element)
      p("-- OK: page element verified [ #{element} ] !")
   end

   # -- verify text
   def verify_text(text)
      p("-- Verifying page text: [ #{text} ]")
      if !@selenium.is_text_present(text)
	 p("-- text not found, page text is currently: " + @selenium.get_body_text() )   
         raise "-- [ERROR] not able to verify text: #{text}"
      end
      p("-- OK: page text verified [ #{text} ] !")
   end

   # -- wait for page to load and verify text
   def wait_for_page_and_verify_text(text)
      @selenium.wait_for_page_to_load(20000)
      check_page_and_verify_text(text)
   end

   # -- check the page for any abnormalities and verify text
   def check_page_and_verify_text(text)
      check_page(@selenium.get_body_text())
      verify_text(text)
   end

   def p(s)
      puts s
   end

   # -- setup proper absolute url based on a given relative url
   def proper_base_url(relative_url)
      p("-- evaluating the proper base url to use based on config settings: " + relative_url)
      if (ENV['qa.base.url'] != nil and ENV['qa.base.url'] != "")
         p("-- using ENV - URL: " + ENV['qa.base.url'])
	 proper_base = (ENV['qa.base.url'] + relative_url)
	 else
            p("-- using env.yaml file URL: " + @base_url)
	    proper_base = (@base_url + relative_url)
	 end
   end

   # -- setup proper file uri needed for any operations involving selenium.attach_file
   def proper_file_uri(file)
      p("-- setting up proper file uri for file: [ #{file} ]")
      case RUBY_PLATFORM
        when /cygwin/, /mswin32/, /i386-mingw32/
           new_path = file.gsub(/C:/,'')
           p("-- new_path (windows only) = #{new_path}")
	   return "file://" + new_path
        else
	   return "file://" + file
      end
   end

   # -- extract page element and compare its value to a given one
   def extract_text_and_compare(location_id, compare_value)
      p("-- checking location_id [ " + location_id + " ] for the following value: " + compare_value)	
      p("-- current value in a given location_id: " + @selenium.get_text(location_id))
      if (@selenium.get_text(location_id) != compare_value)
         raise "-- ERROR: " + compare_value + "not found in [ " + location_id + " ]"
      else
  	 p("-- OK: [ " + compare_value + " ] found!")
      end
   end

   # -- extract text field element and compare its value to a given one
   def extract_value_and_compare(location_id, compare_value)
      p("-- checking location_id [ " + location_id + " ] for the following value: " + compare_value)	
      p("-- current value in a given location_id: " + @selenium.get_text(location_id))
      if (@selenium.get_value(location_id) != compare_value)
         raise "-- ERROR: " + compare_value + "not found in [ " + location_id + " ]"
      else
  	 p("-- OK: [ " + compare_value + " ] found!")
      end
   end

   # -- check pop mail
   def pop_mail
      all_mails = []
      Net::POP.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      Net::POP.start(@common['pop_host'], @common['pop_port'], @common['pop_user_name'], @common['pop_user_password']) do |pop|
         if pop.mails.empty?
            p '-- (pop) No mail.'
         else
            i = 0
            pop.each_mail do |m|
               #exit if i > 20
               p "-- (pop) >>> new message ..."
               all_mails.push(m.pop)
               m.delete
               p "-- (pop) >>> end ..."
               i=i+1
            end
         end
      end
      return all_mails
   end

   # -- clean exit
   def clean_exit(status)
      p "-- exiting test framework..."
      begin
         if (@debug_mode)
            if (status)
               @selenium.close_current_browser_session if defined?(@selenium)
            end
         else
            @selenium.close_current_browser_session if defined?(@selenium)
         end
      rescue => e
         p("ERROR: ")
         p e.inspect
         p e.backtrace
         status = false
      ensure
         if (status)
            p "-- PASSED !"
            exit @CONFIG['STATUS_PASSED']
         else
            p "-- FAILED !"
            exit @CONFIG['STATUS_FAILED']
         end
      end
   end
end
