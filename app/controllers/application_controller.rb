# frozen_string_literal: true
class ApplicationController < ActionController::Base
  helper_method :application_name, :current_year, :library_header_menu_items

  def application_name
    t(:application_name)
  end

  def current_year
    Time.zone.today.year
  end

  def header_user_menu_item
    if current_user
      {
        name: current_user.email,
        component: current_user.email,
        href: '#',
        children: [
          {
            name: 'Log Out',
            component: 'Log Out',
            href: destroy_user_session_path
          }
        ]
      }
    else
      {
        name: 'Log In',
        component: 'Log In',
        href: new_user_session_path
      }
    end
  end

  def library_header_menu_items
    [
      {
        name: 'Data Sets',
        component: 'Data Sets',
        href: data_sets_path
      },
      {
        name: 'Staff Directory',
        component: 'Staff Directory',
        href: staff_directory_path
      },
      {
        name: 'Absolute IDs',
        component: 'Absolute IDs',
        href: absolute_ids_path
      },
      {
        name: 'Barcodes',
        component: 'Barcodes',
        href: barcodes_path
      },
      header_user_menu_item
    ]
  end

  def library_header_attributes
    {
      'menu-items': header_menu_items
    }
  end

  private

  def cache_expiry
    1.hour
  end

  def current_client
    @current_client ||= begin
                          source_client = LibJobs::ArchivesSpace::Client.source
                          source_client.login
                          source_client
                        end
  end

  def json_request?
    request.content_type === "application/json" && request.path_parameters.key?(:format) && request.path_parameters[:format] != 'json'
  end
end
