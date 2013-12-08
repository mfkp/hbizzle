class Movie < ActiveRecord::Base

  validates :title, uniqueness: true

  dragonfly_accessor :poster

  HBO_XML_URL = 'http://catalog.lv3.hbogo.com/apps/mediacatalog/rest/productBrowseService/HBO/category/INDB487'

  def hbo_link
    return "http://www.hbogo.com/#movies/video&assetID=#{self.hbo_id}?videoMode=embeddedVideo"
  end

  def meta_score
    if (self.imdb_rating && self.rotten_critics_score && self.rotten_audience_score)
      return ((self.imdb_rating.to_f*10 + self.rotten_critics_score.to_f + self.rotten_audience_score.to_f) / 3).round
    else
      return 0
    end
  end

  def play
    self.plays += 1
  end

  def self.fetch_update
    self.fetch_listing
    self.fetch_posters
    self.fetch_imdb_info
    self.fetch_rotten_info
  end

  def self.fetch_listing
    xml = Nokogiri::XML(open(HBO_XML_URL))
    hbo_features = Hash.from_xml(xml.to_s)['response']['body']['productResponses']['featureResponse']
    hbo_features.each do |feature|
      if self.where(title: feature['title']).blank?
        @movie = self.new(
          expire: feature['endDate'],
          hbo_id: feature['TKey'],
          title: feature['title'],
          rating: feature['ratingResponse']['ratingDisplay'],
          summary: feature['summary'],
          year: feature['year'].to_s,
          image: feature['imageResponses'].first['resourceUrl']
        )
        @movie.save
      end
    end
  end

  def self.fetch_imdb_info
    Movie.where(imdb_rating: nil || '0.0') do |movie|
      ImdbWorker.perform_async(movie.id)
    end
  end

  def self.fetch_posters
    Movie.where(poster_uid: nil).each do |movie|
      movie.update_poster
    end
  end

  def self.fetch_rotten_info
    Movie.where('rotten_critics_score = ? OR rotten_critics_score = ? OR rotten_audience_score = ? OR rotten_audience_score = ?', '-1', nil, '-1', nil) do |movie|
      RottenWorker.perform_async(movie.id)
    end
  end

  def image_url
    self.poster.remote_url
  end

  def update_poster
  unless self.poster
      PosterWorker.perform_async(self.id)
    end
  end

end