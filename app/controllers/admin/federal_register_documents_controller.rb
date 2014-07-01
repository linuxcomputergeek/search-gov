class Admin::FederalRegisterDocumentsController < Admin::AdminController
  active_scaffold :federal_register_document do |config|
    config.label = 'Federal Register Documents'
    config.actions = [:list, :show]
    config.list.columns = [:document_number,
                           :document_type,
                           :title,
                           :html_url,
                           :publication_date,
                           :comments_close_on,
                           :created_at,
                           :updated_at]
    list.sorting = { publication_date: 'DESC', id: 'ASC' }

    config.actions.add :field_search
    config.field_search.columns = [:federal_register_agencies, :document_type, :document_number]
  end
end