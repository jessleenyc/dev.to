module ClassifiedListingsToolkit
  extend ActiveSupport::Concern

  # this looks like it should be a model method
  def unpublish_listing
    @classified_listing.update(published: false)
    @classified_listing.remove_from_index!
  end

  # this looks like it should be a model method
  def publish_listing
    @classified_listing.update(published: true)
    @classified_listing.index!
  end

  # [1]
  def update_listing_details
    # could keep it simpler with this. If something shouldn't be updated, just remove from the hash
    @classified_listing.update(listing_params)
  end

  # [1]
  def bump_listing
    @classified_listing.update(bumped_at: Time.current)
  end

  def clear_listings_cache
    cb = CacheBuster.new
    cb.bust("/listings")
    cb.bust("/listings?i=i")
    cb.bust("/listings/#{@classified_listing.category}/#{@classified_listing.slug}")
    cb.bust("/listings/#{@classified_listing.category}/#{@classified_listing.slug}?i=i")
    cb.bust("/listings/#{@classified_listing.category}")
  end

  # [1]: since it's only 1 line, those may not need to be extracted to a concern
end
