require 'sinatra'
require 'yaml-model'

Change = Class.new YAML_Model

TITLE_FORMAT = /[a-z]+(?:-[a-z]+)*/

class Page < YAML_Model
  has :changes, Change
  type :title, String do |value|
    raise "Invalid title format" unless value =~ /^#{TITLE_FORMAT}$/
  end
  init :title
end

class Change < YAML_Model
  type :page, Page
  type :when, Time, :default => Time.now
  type :content, String do |value|
    raise "Content cannot be empty" if value.strip.empty?
  end
  init :page, :content
end

YAML_Model.filename = 'wiki.yaml'

class String
  def to_title
    split('-').map{|n|n.capitalize}.join(' ')
  end
  def to_content
    split("\n").map{|n|"<p>#{n}</p>"}.join
  end
end

get '/' do
  redirect '/welcome'
end

get '/source' do
  response[ 'Content-Type' ] = 'text/plain'
  File.read( __FILE__ )
end

get %r{^/(\d+)$} do |change_id|
  change = Change[change_id.to_i]
  redirect :/ unless change
  <<HistoricalPage
<h1>Historical Page</h1>
<h2>#{change.page.title.to_title}</h2>
<h3>#{change.when}</h3>
#{change.content.to_content}
HistoricalPage
end

get %r{^/(#{TITLE_FORMAT})$} do |title|
  page = Page.filter( :title => title ).first
  params['mode'] = 'edit' unless page
  ( change = page.changes.sort{|a,b|b.when<=>a.when}.first ) if page
  "<h1>#{title.to_title}</h1>" + ( page ? "<sup>#{change.when}<a href</sup>" : '' ) +
  %{<ul style="float:right;list-style:none">} + Page.all.map{|n|n.title}.sort.map{|n|%{<li><a href="/#{n}">#{n.to_title}</a></li>}}.join + "</ul>" +
  if params['mode'] == 'edit'
    %{<form method="POST"><textarea name="content">#{ page ? change.content : ''}</textarea><input type="submit"/></form>}
  else
    change.content.to_content + %{<hr/><a href="?mode=edit">edit</a><h2>History</h2><ul>} +
      page.changes.sort{|a,b|b.when<=>a.when}.map{|n|%{<li><a href="/#{n.id}">#{n.when}</a></li>}}.join + "</ul>"
  end 
end

post %r{^/(#{TITLE_FORMAT})$} do |title|
  page = Page.filter( :title => title ).first
  page ||= Page.create( title )
  change = Change.create( page, params['content'] )
  redirect "/#{title}"
end
