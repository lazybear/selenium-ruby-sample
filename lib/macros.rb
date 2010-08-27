require 'lib/ruby_suite'

class GoogleSearchMacro
    def initialize(suite)
       @suite        = suite
       @suite.set_test_name(self.class.name)
    end

    # -- test begins
    def run_test
       @suite.selenium.open(@suite.common['google_home_page_url'])
       @suite.wait_for_page_and_verify_text(@suite.common['google_home_page_verify_text'])
       @suite.p("-- clicking on: [" + @suite.common['google_advanced_search_link'] + "] link")
       @suite.selenium.click(@suite.common['google_advanced_search_link'])
       @suite.wait_for_page_and_verify_text(@suite.common['google_advanced_search_page_verify_text'])
    end
end
