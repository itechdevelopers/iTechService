class ChangeWishlistToJsonbOnUsers < ActiveRecord::Migration[5.1]
  def up
    # Step 1: Convert string[] to jsonb (plain array of strings as JSON)
    execute <<-SQL
      ALTER TABLE users
      ALTER COLUMN wishlist DROP DEFAULT,
      ALTER COLUMN wishlist TYPE jsonb USING COALESCE(array_to_json(wishlist)::jsonb, '[]'::jsonb),
      ALTER COLUMN wishlist SET DEFAULT '[]'::jsonb;
    SQL

    # Step 2: Transform ["url1", "url2"] into [{"url":"url1","added_at":"..."}, ...]
    execute <<-SQL
      UPDATE users
      SET wishlist = COALESCE(
        (SELECT jsonb_agg(
          jsonb_build_object('url', elem, 'added_at', TO_CHAR(NOW(), 'YYYY-MM-DD'))
        )
        FROM jsonb_array_elements_text(wishlist) AS elem
        WHERE elem IS NOT NULL AND elem != ''),
        '[]'::jsonb
      )
      WHERE wishlist IS NOT NULL AND wishlist != '[]'::jsonb;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE users
      ALTER COLUMN wishlist DROP DEFAULT,
      ALTER COLUMN wishlist TYPE varchar[]
        USING COALESCE(
          ARRAY(SELECT elem->>'url' FROM jsonb_array_elements(wishlist) AS elem),
          ARRAY[]::varchar[]
        ),
      ALTER COLUMN wishlist SET DEFAULT ARRAY[]::varchar[];
    SQL
  end
end
