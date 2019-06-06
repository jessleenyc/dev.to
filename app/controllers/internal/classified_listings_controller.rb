class Internal::ClassifiedListingsController < Internal::ApplicationController
  include ClassfiedListingScoped
  include ClassifiedListingsToolkit

  layout "internal"

  before_action :set_classified_listing, except: :index
  after_action :clear_listings_cache, only: :update

  def index
    @classified_listings = ClassifiedListing.page(params[:page]).order("bumped_at DESC").per(50)
    @classified_listings = @classified_listings.joins(:user).where("classified_listings.title ILIKE :search OR users.username ILIKE :search", search: "%#{params[:search]}%") if params[:search].present?
  end

  def edit; end

  def update
    bumped_at = bumped ? { bumped_at: Time.current } : {}
    @classified_listing.update listing_params.merge(bumped_at)

    flash[:success] = "Listing updated successfully"
    redirect_to "/internal/listings/#{@classified_listing.id}/edit"
  end

  def destroy
    @classified_listing.destroy

    flash[:warning] = "'#{@classified_listing.title}' was destroyed successfully"
    redirect_to "/internal/listings"
  end

  private

  def listing_params
    allowed_params = %i[published body_markdown title category tag_list action]
    params.require(:classified_listing).permit(allowed_params)
  end

  def bumped?
    listing_params[:action] == "bump"
  end
end
