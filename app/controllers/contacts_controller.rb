#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class ContactsController < ApplicationController
  before_action :authenticate_user!

  layout ->(c) { request.format == :mobile ? "application" : "with_header_with_footer" }
  use_bootstrap_for :index, :spotlight

  def index
    respond_to do |format|

      # Used for normal requests to contacts#index
      format.html { set_up_contacts }

      # Used by the mobile site
      format.mobile { set_up_contacts_mobile }

      # Used to populate mentions in the publisher
      format.json {
        aspect_ids = params[:aspect_ids] || current_user.aspects.map(&:id)
        @people = Person.all_from_aspects(aspect_ids, current_user).for_json
        render :json => @people.to_json
      }
    end
  end

  def spotlight
    @spotlight = true
    @people = Person.community_spotlight
  end

  private

  def set_up_contacts
    c = Contact.arel_table
    @contacts = case params[:set]
      when "only_sharing"
        current_user.contacts.only_sharing.to_a.sort_by { |c| c.person.name }
      when "all"
        current_user.contacts.to_a.sort_by { |c| c.person.name }
      else
        if params[:a_id]
          @aspect = current_user.aspects.find(params[:a_id])
          @contacts_in_aspect = @aspect.contacts.includes(:aspect_memberships, :person => :profile).to_a.sort_by { |c| c.person.name }
          if @contacts_in_aspect.empty?
            @contacts_not_in_aspect = current_user.contacts.includes(:aspect_memberships, :person => :profile).to_a.sort_by { |c| c.person.name }
          else
            @contacts_not_in_aspect = current_user.contacts.where(c[:id].not_in(@contacts_in_aspect.map(&:id))).includes(:aspect_memberships, :person => :profile).to_a.sort_by { |c| c.person.name }
          end
          @contacts_in_aspect + @contacts_not_in_aspect
        else
          current_user.contacts.receiving.to_a.sort_by { |c| c.person.name }
        end
    end
    @contacts_size = @contacts.length
  end
  
  def set_up_contacts_mobile
    @contacts = case params[:set]
      when "only_sharing"
        current_user.contacts.only_sharing
      when "all"
        current_user.contacts
      else
        if params[:a_id]
          @aspect = current_user.aspects.find(params[:a_id])
          @aspect.contacts
        else
          current_user.contacts.receiving
        end
    end
    @contacts = @contacts.for_a_stream.paginate(:page => params[:page], :per_page => 25)
    @contacts_size = @contacts.length
  end
end
