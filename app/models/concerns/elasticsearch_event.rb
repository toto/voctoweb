require 'active_support/concern'

module ElasticsearchEvent
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks unless ENV['SKIP_ELASTICSEARCH']

    index_name "media-event-#{Rails.env}"
    document_type 'event'

    def as_indexed_json(_options = {})
      as_json(
        only: %i(title subtitle description persons length release_date date updated_at slug),
        id: :guid,
        include: { conference: { only: %i(title acronym) }
      })
    end
  end

  class_methods do
    def query(term)
      term ||= ''
      search_for query: {
        function_score:  {
          query:  {
            bool:  {
              disable_coord:  true,
              should:  [
                {
                  multi_match: {
                    query: term,
                    fields: [
                      'title',
                      'conference.title'
                    ],
                    type: 'phrase',
                    boost: 9000
                  }
                },
                {
                  multi_match: {
                    query: term,
                    fields: [
                      'title'
                    ],
                    operator: 'and',
                    boost: 4000
                  }
                },
                {
                  multi_match:  {
                    query:  term,
                    fields:  [
                      'title^20',
                      'subtitle^3',
                      'persons^4',
                      'slug^2',
                      'remote_id^2',
                      'conference.acronym^2',
                      'conference.title^2',
                      'description^1'
                    ],
                    type:  'best_fields',
                    operator:  'and',
                    fuzziness:  1
                  }
                }
              ]
            }
          },
          boost:  1.2,
          boost_mode: 'avg',
          functions: [
            { gauss: { date: { scale: '730d', decay: 0.5 } } }
          ]
        }
      }
    end

    def query_persons(term)
      term ||= ''
      search_for query: {
        function_score:  {
          query:  {
            bool:  {
              disable_coord:  true,
              should:  [
                {
                  multi_match:  {
                    query:  term,
                    fields:  [
                      'persons^3'
                    ],
                    type:  'best_fields',
                  }
                }
              ]
            }
          },
          boost:  1.2,
          functions:  [
            { gauss:  { date:  { scale:  '730d', decay:  0.9 } } }
          ]
        }
      }
    end

    # avoid conflict with active admins ransack #search method
    def search_for(*args, &block)
      __elasticsearch__.search(*args, &block)
    end
  end
end
