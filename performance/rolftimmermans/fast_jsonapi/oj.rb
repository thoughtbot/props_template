require 'jsonapi/serializer'
require 'oj'

Article = Struct.new(:id, :title, :body, :date, :references, :comments, :author, :reference_ids, :comment_ids, :author_id)
Comment = Struct.new(:id, :email, :body, :date, :author, :author_id)
Author = Struct.new(:id, :name, :birthyear, :bio)
Reference = Struct.new(:id, :name, :url)
author = Author.new({
  id: SecureRandom.uuid,
  name: $author.name,
  birthyear: $author.birthyear,
  bio: $author.bio
})

references = $arr.map{|ref| Reference.new({
  id: SecureRandom.uuid,
  name: "Introduction to profiling",
  url: "http://example.com",
})}

comments = $arr.map{|comment|
  comment_author = Author.new({
    id: SecureRandom.uuid,
    name: $author.name,
    birthyear: $author.birthyear,
    bio: $author.bio,
  })

  Comment.new({
    id: SecureRandom.uuid,
    author: comment_author,
    author_id: comment_author.id,
    email: "rolf@example.com",
    body: "Great article",
    date: $now,
  })
}


article = Article.new({
  id: SecureRandom.uuid,
  author_id: author.id,
  author: author,
  title: "Profiling Jbuilder",
  body: "How to profile Jbuilder",
  date: $now,
  references: references,
  reference_ids: references.map(&:id),
  comments: comments,
  comment_ids: comments.map(&:id)
})

class AuthorSerializer
  include JSONAPI::Serializer
  attributes :name, :birthyear, :bio
end

class ReferenceSerializer
  include JSONAPI::Serializer
  attributes :name, :url
end

class CommentSerializer
  include JSONAPI::Serializer
  attributes :email, :body, :date
  has_one :author
end

class ArticleSerializer
  include JSONAPI::Serializer
  attributes :title, :body, :date
  has_one :author
  has_many :comments
  has_many :references
end

ARTICLE = article

__SETUP__

Oj.dump(ArticleSerializer.new(ARTICLE).serializable_hash)
