#!/usr/bin/env ruby
require 'lib/base_test'

# @author Alexandre Berman, Lazybear Consulting (sashka@lazybear.net)
# @executeArgs
# @keywords example
# @description basic Google search test

class GoogleSearchTest < BaseTest

    # -- test begins
    def run_main
       GoogleSearchMacro.new(@suite).run_test
    end

end

GoogleSearchTest.new.run_test
