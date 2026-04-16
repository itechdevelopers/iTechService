class RestructureCheckListResponsesFormat < ActiveRecord::Migration[5.1]
  # Convert flat format { "42": "yes" } to nested { "42": { "answer": "yes" } }
  # Uses raw SQL to avoid double-serialization from `serialize :responses, JSON`

  def up
    execute <<-SQL.squish
      UPDATE check_list_responses
      SET responses = (
        SELECT json_object_agg(
          key,
          json_build_object('answer', CASE WHEN value::text = '"true"' THEN 'yes' ELSE trim(both '"' from value::text) END)
        )::text
        FROM json_each(responses::json)
      )
      WHERE responses IS NOT NULL
        AND responses != '{}'
        AND responses != ''
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE check_list_responses
      SET responses = (
        SELECT json_object_agg(key, (value->>'answer'))::text
        FROM json_each(responses::json)
      )
      WHERE responses IS NOT NULL
        AND responses != '{}'
        AND responses != ''
    SQL
  end
end
