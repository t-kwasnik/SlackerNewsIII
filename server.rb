require 'sinatra'
require 'pg'

def grab_contents(table)
  connection = PG.connect(dbname: 'slacker_news')
  articles = connection.exec("SELECT * FROM #{table}")
  connection.close
  articles
end

def save_article(title, url, description)
  connection = PG.connect(dbname: 'slacker_news')
  connection.exec_params("INSERT INTO articles (title,url,description,time) VALUES ($1, $2, $3, NOW())", [title,url,description])
  connection.close
end

def save_comment(parent_id, article_id, comment)
  connection = PG.connect(dbname: 'slacker_news')
  connection.exec_params("INSERT INTO comments (parent_comment,article_id,comment,time)  VALUES ($1, $2, $3, NOW())", [parent_id, article_id, comment])
  connection.close
end

def find_subcomments(initial_hash)
  initial_hash["subcomments"] = []
  grab_contents("comments").to_a.each do |sub_comment|
    if ( initial_hash["comment_id"] == sub_comment["parent_comment"] ) && ( initial_hash["comment_id"] != sub_comment["comment_id"] )
      initial_hash["subcomments"] << sub_comment.to_hash
    end
  end
  if initial_hash["subcomments"] == []
    initial_hash.delete("subcomments")
  else
    initial_hash["subcomments"].each do |subsubcomment|
      find_subcomments(subsubcomment)
    end
  end
  initial_hash
end

def get_articles
  all_articles = []
  grab_contents("articles").to_a.each do |article|
    article["comments"] = []
    grab_contents("comments").to_a.each do |comment|
      if ( comment["parent_comment"] == comment["comment_id"] ) && ( comment["article_id"] == article["article_id"] )
         article["comments"] << find_subcomments(comment)
      end
    end
    all_articles << article
  end
  all_articles
end

def get_matches(csv, field, term)
  matches = []
  grab_contents(csv).to_a.each do |row|
    matches << row if row[field] == term
  end
  matches.reverse
end

def get_comments
  all_rows = []
  grab_contents("comments").to_a.each do |row|
    if row["comment_id"] != row["parent_comment"]
      row["response_to"] = get_matches("comments","comment_id",row["parent_comment"])[0]["comment"]
    end
    row["article"] = get_matches("articles","article_id", row["article_id"])
    all_rows << row
  end
  all_rows.reverse
end

def url_exists?(url)
  get_articles.each do |article|
    article["url"] == url ? ( return true ) : (return false )
  end
end

get "/submit"  do
  @populated_info = {}
  @missing_info = []
  erb :submit
end

get "/comments"  do
  @comments = get_comments
  erb :comments
end

get "/addcomment/:article_id"  do
  @article_info = ""
  get_articles.each {|article| @article_info = article if article["article_id"] == params[:article_id] }
  erb :addcomment
end

get "/addresponse/:article_id/:parent_comment"  do
  @comment_info = ""
  get_comments.reverse.each { |comment| @comment_info = comment if comment["comment_id"].to_i == params[:parent_comment].to_i }
  erb :addresponse
end

post "/addcomment"  do
  params[:parent_comment] == nil ? ( parent_comment = -1 ) : ( parent_comment = params[:parent_comment] )
  save_comment(parent_comment, params[:article_id], params[:comment] )
  redirect "/"
end

post "/submit"  do
  @populated_info = {}
  @missing_info = []
  checks_failed = 0

  [:title,:url,:descriptor].each do |check|
    if params[check] == ""
      @missing_info << "Please enter information for ".concat(check.to_s.upcase)
      checks_failed +=1
    else
      @populated_info[check] = params[check]
    end
  end

  if params[:descriptor].length < 20
    @missing_info << "Please enter a longer description"
    checks_failed +=1
  end

  if url_exists?(params[:url]) == true
    @missing_info << "The URL is already listed..."
    checks_failed +=1
  end

  if checks_failed == 0
    id = get_articles.length
    save_article(params[:title],params[:url],URI.encode(params[:descriptor]))
    redirect "/"
  else
    erb :submit
  end
#
end

get "/*"  do
  @articles = get_articles
  erb :main
end
