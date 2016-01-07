moment = require './moment.min.js' 

DateTimeFormatter =
	format: (dateTime, softwareSlug) ->
		if softwareSlug == 'renegade'
			return this.formatRenegade dateTime
			
	formatRenegade: (dateTime) ->
		return moment(Date.parse(dateTime)).format 'h:mma[&nbsp;&nbsp;]ddd MMMM D, YYYY'

module.exports = DateTimeFormatter

