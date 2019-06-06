class ClassifiedListingsController < ApplicationController
  include ClassfiedListingScoped
  include ClassifiedListingsToolkit

  before_action :set_classified_listing, only: %i[edit update]
  before_action :set_cache_control_headers, only: %i[index]
  before_action :authenticate_user!, only: %i[edit update new]

  after_action :verify_authorized, only: %i[edit update]

  def index
    @displayed_classified_listing = ClassifiedListing.find_by!(slug: params[:slug]) if params[:slug]
    mod_page if params[:view] == "moderate"
    @classified_listings = if params[:category].blank?
                             ClassifiedListing.where(published: true).order("bumped_at DESC").limit(12)
                           else
                             []
                           end

    set_surrogate_key_header "classified-listings-#{params[:category]}"
  end

  def new
    @classified_listing = ClassifiedListing.new
    @organizations = current_user.organizations
    @credits = current_user.credits.where(spent: false)
  end

  def edit
    authorize @classified_listing
    @organizations = current_user.organizations
    @credits = current_user.credits.where(spent: false)
  end

  def create
    additional_args = { bumped_at: Time.current, published: true, user_id: current_user.id }
    @classified_listing = ClassifiedListing.new(listing_params.merge(additional_args))

    @number_of_credits_needed = ClassifiedListing.cost_by_category(@classified_listing.category)
    @org = Organization.find_by(id: @classified_listing.organization_id)
    # 1 figure out if user has enough cash
    # 2 actually create?
    available_org_credits = @org.credits.where(spent: false) if @org
    available_individual_credits = current_user.credits.where(spent: false)

    if @org && available_org_credits.size >= @number_of_credits_needed
      create_listing(available_org_credits)
    elsif available_individual_credits.size >= @number_of_credits_needed
      create_listing(available_individual_credits)
    else
      redirect_to "/credits"
    end
  end

  def create_listing(credits)
    # this will 500 for now if they don't belong in the org
    if @classified_listing.organization_id.present?
      authorize @classified_listing, :authorized_organization_poster?
    if @classified_listing.save
      clear_listings_cache
      credits.limit(@number_of_credits_needed).update_all(spent: true)
      @classified_listing.index!
      redirect_to "/listings"
    else
      @credits = current_user.credits.where(spent: false)
      @classified_listing.cached_tag_list = listing_params[:tag_list]
      @organizations = current_user.organizations
      render :new
    end
  end

  def update
    authorize @classified_listing
    available_credits = current_user.credits.where(spent: false)
    number_of_credits_needed = ClassifiedListing.cost_by_category(@classified_listing.category) # Bumping

    # need more info to refactor this
    # if something_action_that_cost_money
    #
    # else other_things
    #
    # end
    if listing_params[:action] == "bump"
      bump_listing
      if available_credits.size >= number_of_credits_needed
        @classified_listing.save
        available_credits.limit(number_of_credits_needed).update_all(spent: true)
      end
    elsif listing_params[:action] == "unpublish"
      unpublish_listing
    elsif listing_params[:body_markdown].present? && @classified_listing.bumped_at > 24.hours.ago
      update_listing_details
    end
    clear_listings_cache
    redirect_to "/listings"
  end

  private

  def listing_params
    accessible = %i[title body_markdown category tag_list contact_via_connect organization_id action]
    params.require(:classified_listing).permit(accessible)
  end

  def mod_page
    redirect_to "/internal/listings/#{@displayed_classified_listing.id}/edit"
  end
end
