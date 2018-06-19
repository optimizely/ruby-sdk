# Generate API Documentation
### Steps
* To install YARD Run 

`$ gem install yard`

* There's a possible chance your Ruby install lacks RDoc, which is occasionally used by YARD to convert markup to HTML. If RDoc not installed, install by issuing:
* `$ apt-get install rdoc`

* `$ yardoc 'lib/**/*.rb'...etc...`

**OR**

* `$ yardoc 'lib/*.rb' 'lib/optimizely/event_dispatcher.rb' 'lib/optimizely/notification_center.rb' 'lib/optimizely/logger.rb' 'lib/optimizely/error_handler.rb' 'lib/optimizely/user_profile_service.rb'`

* This will generate HTML documentation in **doc** directory.
* Open **index.html** in **doc** directory.

### Notes
* Tool: [YARD](https://github.com/lsegal/yard)
