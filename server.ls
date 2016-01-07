config = require './config'

moment = require './moment.min.js'
dtf = require './DateTimeFormatter'

express = require 'express'
kleiDust = require 'klei-dust'
async = require 'async'

mongo = require 'mongojs'

port = config.port

dbURL = "mongodb://#{config.dbUser}:#{config.dbPassword}@#{config.dbServer}/#{config.dbName}"
db = mongo dbURL, ['feed', 'software'], {authMechanism: 'ScramSHA1'}

defaultTemplate = 'renegade'


app = express()

app.configure ->
	app.set 'views', __dirname + '/views'
	app.engine 'dust', kleiDust.dust
	app.set 'view engine', 'dust'
	app.set 'view options', {layout: false}

	app.use express.static __dirname + '/public', {redirect: false}
    
	app.use express.bodyParser()
	app.use express.cookieParser()

	app.use express.session({
		secret: 'very_unique_secret_string',
		cookie: { maxAge: 1800000 }
	})

	app.use app.router

	app.get '/', (req, res) ->
		if !req.cookies['template'] || req.cookies['template'] == 'undefined'
			template = defaultTemplate
			res.cookie 'template', defaultTemplate
		else
			template = req.cookies['template']

		template = 'renegade'

		async.parallel([
			(callback) ->
				db.software.find(
					{},
					(err, data) ->
						if !err && data
							callback null, data
						else
							callback null, null
				)
			,
			(callback) ->
				db.feed.find(
					{},
					(err, data) ->
						if !err && data
							callback null, data
						else
							callback null, null
				)
			,
			(callback) ->
				db.software.find(
					{slug: template},
					(err, data) ->
						if !err && data
							callback null, data
						else
							callback null, null
				)
		], (err, results) ->
			renderHome res, results[0], results[1], results[2]
		)

	app.get '/software/:slug', (req, res) ->
		slug = req.params.slug
		res.cookie 'template', slug

		res.redirect('/')

	app.get	'/article/:templateSlug/:feedSlug/:articleSlug', (req, res) ->
		templateSlug = req.params.templateSlug
		feedSlug = req.params.feedSlug
		articleSlug = req.params.articleSlug
		
		async.parallel([	
			(callback) ->
				db.software.find(
					{},
					(err, data) ->
						if !err && data         
							callback null, data
						else
							callback null, null
				)
			,
			(callback) ->
				db.feed.findOne(
					{slug: feedSlug, 'articles.slug': articleSlug},
					{},
					(err, data) ->
						if !err && data         
							callback null, data
						else
							callback null, null
				)
			,
			(callback) ->
				db.software.findOne(
					{slug: templateSlug},
					(err, data) ->
						if !err && data         
							callback null, data
						else
							callback null, null
				)			
		], (err, results) ->
			software = results[0]
			data = results[1]
			template = results[2]
					
			count = 0
					
			if data
				article = null
			
				data.articles.forEach (item) ->
					count++

					if item.slug == articleSlug
						article := item			

				renderArticle res, software, data, article, count, template
			else
				console.log 'NO DATA'
				renderArticle res, software, null, null, count, template
		)


renderHome = (res, software, feeds, template) ->
	template = template[0]
	
	if !software || !feeds || !template
		res.render 'error'
		return

	res.render(
		'home',
		{
			software: software,
			feeds: feeds,
			templateName: template['name']
			templateSlug: template['slug']
		}
	)


renderArticle = (res, software, feed, article, numArticles, template) ->
	if !software || !article || !template
		res.render 'error'
		return

	res.render(
		template.slug,
		{
			software: software,
			feed: feed,
			article: article,
			numArticles: numArticles,
			
			template: template,
			
			publishedDate: dtf.format(article.published_date, template.slug)
			nowDate: moment().format 'hh:mm:ss'
		}
	)


app.listen port
console.log 'Listening on port ' + port

