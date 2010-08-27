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

require 'lib/ruby_suite'

class BaseTest
    attr_accessor :suite, :passed
    def initialize
       @suite  = RubySuite.new(:test_name => self.class.name)
       @passed = false
    end

    # -- test begins
    def run_test
       begin
          setup
          run_main
          @passed = true
       rescue => e
          @suite.p "FAILED: "
          @suite.p e.inspect
          @suite.p e.backtrace
       ensure
          teardown
          @suite.clean_exit(@passed)
       end
    end

    # -- this method is overriden in subclass
    def run_main
    end

    # -- this method is overriden in subclass
    def setup
       @suite.p "\n:: [SETUP]\n"
    end

    # -- this method is overriden in subclass
    def teardown
       @suite.p "\n:: [TEARDOWN]\n"
    end
end
