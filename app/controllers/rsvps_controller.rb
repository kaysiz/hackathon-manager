class RsvpsController < ApplicationController
  before_action :logged_in
  before_action :check_user_has_questionnaire
  before_action :find_questionnaire
  before_action :require_accepted_questionnaire

  def logged_in
    authenticate_user!
  end

  # GET /rsvp
  def show
  end

  # GET /rsvp/accept
  def accept
    @questionnaire.acc_status = "rsvp_confirmed"
    @questionnaire.acc_status_author_id = current_user.id
    @questionnaire.acc_status_date = Time.now
    if @questionnaire.save
      flash[:notice] = "Thank you for confirming your attendance! You're all set to attend."
      flash[:notice] += " See below for additional bus information." if BusList.any?
    else
      flash[:alert] = rsvp_error_notice
    end
    redirect_to rsvp_path
  end

  # GET /rsvp/deny
  def deny
    @questionnaire.acc_status = "rsvp_denied"
    @questionnaire.acc_status_author_id = current_user.id
    @questionnaire.acc_status_date = Time.now
    if @questionnaire.save
      flash[:notice] = "Your RSVP has been updated."
    else
      flash[:alert] = rsvp_error_notice
    end
    redirect_to rsvp_path
  end

  # PUT /rsvp
  # rubocop:disable CyclomaticComplexity
  # rubocop:disable PerceivedComplexity
  def update
    unless @questionnaire.update_attributes(params.require(:questionnaire).permit(:agreement_accepted, :phone))
      flash[:alert] = @questionnaire.errors.full_messages.join(", ")
      redirect_to rsvp_path
      return
    end

    unless ["rsvp_confirmed", "rsvp_denied"].include? params[:questionnaire][:acc_status]
      flash[:alert] = "Please select a RSVP status."
      redirect_to rsvp_path
      return
    end

    @questionnaire.acc_status_date = Time.now if @questionnaire.acc_status != params[:questionnaire][:acc_status]
    @questionnaire.acc_status = params[:questionnaire][:acc_status]
    @questionnaire.acc_status_author_id = current_user.id

    new_bus_list_id = params[:questionnaire][:bus_list_id].presence
    new_bus_list = new_bus_list_id && BusList.find(new_bus_list_id)
    is_joining_bus = new_bus_list.present? && @questionnaire.bus_list != new_bus_list
    if is_joining_bus && new_bus_list.full?
      if @questionnaire.bus_list_id?
        flash[:alert] = "Sorry, that bus is full. You are still signed up for the '#{@questionnaire.bus_list.name}' bus."
      else
        flash[:alert] = "Sorry, that bus is full. You may need to arrange other plans for transportation."
      end
    else
      @questionnaire.bus_list = new_bus_list
      @questionnaire.bus_captain_interest = params[:questionnaire][:bus_captain_interest]
    end

    unless @questionnaire.save
      flash[:alert] = @questionnaire.errors.full_message.join(", ")
      redirect_to rsvp_path
      return
    end

    if flash[:notice].blank? && flash[:alert].blank?
      flash[:notice] = "Your RSVP has been updated."
      flash[:notice] += " See below for additional bus information!" if @questionnaire.bus_list_id?
    end

    redirect_to rsvp_path
  end
  # rubocop:enable CyclomaticComplexity
  # rubocop:enable PerceivedComplexity

  private

  def rsvp_error_notice
    hackathon_name = HackathonConfig['name']
    "There was an error submitting your response, please check over your application and try again. Did you accept the #{hackathon_name} Agreement?"
  end

  def find_questionnaire
    @questionnaire = current_user.questionnaire
  end

  def check_user_has_questionnaire
    redirect_to new_questionnaires_path if current_user.questionnaire.nil?
  end

  def require_accepted_questionnaire
    return if @questionnaire.can_rsvp? || @questionnaire.checked_in?

    redirect_to new_questionnaires_path
  end
end
