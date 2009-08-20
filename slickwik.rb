#/usr/bin/ruby

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'rdiscount'
require 'erb'

### Data Mapper

configure do
  DataMapper.setup(:default, "sqlite3:///#{Dir.pwd}/slickwik.db")
end

class Page
    include DataMapper::Resource
    property :slug,       String, :key => true
    property :created_at, DateTime, :default => Proc.new { |r, p| Time.now }
    property :content,    Text, :default => ''
    property :version,    Integer, :default => 1
    has n, :changes
end

class Change
    include DataMapper::Resource
    property :id,         Serial
    property :diff,       Text, :default => ''
    property :created_at, DateTime, :default => Proc.new { |r, p| Time.now }
    property :version,    Integer
    belongs_to :page
    default_scope(:default).update(:order => [:version.desc])
end

DataMapper.auto_upgrade!

### helpers

helpers do
  def wik(str)
    if not str.nil?
      wik = RDiscount.new(str).to_html
      wik.gsub(/\[\[([0-9a-zA-Z_, \-]+?)\]\]/, '<a href="/\1">\1</a>')
    end
  end
end

### helper functions

def slugify(str)
	str = str.gsub(/[^a-zA-Z0-9_ ]/,"")
	str = str.gsub(/[ ]+/," ")
	str = str.gsub(/ /,"_")
end

### routes

get '/' do
  redirect "/Home"
end

get '/:slug' do
  @slug = slugify params[:slug]
  @page = Page.first(:slug.like => @slug)
  if @page.nil?
    @page = Page.new(:slug => @slug)
    @page.save
  end
  @title = @page.slug.gsub(/_/," ")
  erb :index
end

post '/:slug' do
  
  page_slug = slugify params[:slug]
  page = Page.first(:slug.like => page_slug)
  
  new_content = params[:content]
  
  if page.nil?
    
    page = Page.new(:slug => page_slug, :content => new_content)
    page.save

    redirect "/#{page_slug}"
  
  elsif params[:delete] == 'delete'
    
    page.destroy
    content_type :json
    "{status: 'ok'}"
    
  else
    
    diff = nil # do real diff here of @page.content and new_content
    
    version = page.version + 1
    
    page.content = new_content
    page.version = version
    page.changes << Change.new(:diff => diff, :version => version)
    page.save

    redirect "/#{page_slug}"
    
  end
  
end