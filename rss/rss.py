#coding=utf-8

import urllib, unidecode, re

from database import *
from dateutil.parser import parse
from feeds import *
from mongoengine import *
from xml.etree import ElementTree


class Article(EmbeddedDocument):
	number = IntField(required=True)
	
	title = StringField(required=True)
	slug = StringField(required=True)
	
	link = StringField(required=True)
	published_date = DateTimeField(required=True)
	creator = StringField(required=False)
	
	description = StringField(required=True)
	content = StringField(required=False)

class Feed(Document):
	name = StringField(required=True)
	slug = StringField(required=True)
	
	url = StringField(required=True)
	format = StringField(required=True)
	articles = ListField(EmbeddedDocumentField(Article))


# Modified from http://stackoverflow.com/questions/5574042/string-slugification-in-python

def slugify(s):
	slug = s.lower()
		
	slug = re.sub("’", "'", slug)		
	slug = re.sub(r"\'s[$\W\-]+", " ", slug)
	slug = re.sub(r"\W+\&\W+", " and ", slug)               
	slug = re.sub(r"\.", "", slug)
		
	slug = slug.strip()

	if (isinstance(slug, unicode)):
		slug = unidecode.unidecode(slug)

	slug = re.sub(r'\W+', '-', slug)
	slug = re.sub(r'[^a-z0-9\-]+', '', slug)        
	slug = re.sub(r'[\-]+', '-', slug)

	slug = re.sub(r'-+$', '', slug)
	slug = re.sub(r'^-+', '', slug) 
	slug = re.sub(r'-+the$', '', slug)
		
	return slug


connect(db_name, host=db_server, port=db_port, username=db_user, password=db_pwd)

for feed in Feed.objects:
	feed.delete()
	
for feed in feeds:
	address = feed['url']	
	rss = ElementTree.parse(urllib.urlopen(address))
	
	items = rss.findall('./channel/item')
	articles = []
	
	count = 0
	
	for item in items:
		count += 1
		
		title = item.find('title').text.encode('utf-8')
		link = item.find('link').text.encode('utf-8')
		
		temp_date = item.find('pubDate').text.encode('utf-8')
		published_date = parse(temp_date)
		
		creator = item.find('{http://purl.org/dc/elements/1.1/}creator').text.encode('utf-8')

		description = item.find('description').text.encode('utf-8')
		content = item.find('{http://purl.org/rss/1.0/modules/content/}encoded').text.encode('utf-8')	
		
		new_article = Article(
			number = count,
			title = title,
			slug = slugify(title),
			link = link,
			published_date = published_date,
			creator = creator,
			description = description,
			content = content
		)
		
		articles.append(new_article)

	new_feed = Feed(name=feed['name'], slug=slugify(feed['name']), url=feed['url'], format='RSS', articles=articles)
	
	try:
		new_feed.save()
	except OperationError:
		print 'SAVE ERROR'

