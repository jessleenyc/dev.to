module ClassfiedListingScoped
  extend ActiveSupport::Concern

  private

  def set_classified_listing
    @classified_listing = ClassifiedListing.find(params[:id])
  end
end
