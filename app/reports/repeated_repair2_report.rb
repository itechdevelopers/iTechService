# frozen_string_literal: true

class RepeatedRepair2Report < BaseReport
  def call
    sql = <<-SQL
      select s1.*, s2.c c1
      from service_jobs s1
               left join (
          SELECT item_id, count(*) c FROM service_jobs
          where item_id is not null
            and created_at >= '#{Date.parse(start_date).iso8601}'
            and created_at <= '#{Date.parse(end_date).iso8601}'
            #{"and location_id = #{department.id}" if department}
          GROUP BY item_id HAVING count(*) > 1
      ) s2 on s1.item_id = s2.item_id

      where s1.item_id is not null and s2.c > 1
        and created_at >= '#{Date.parse(start_date).iso8601}'
        and created_at <= '#{Date.parse(end_date).iso8601}'
        #{"and location_id = #{department.id}" if department}
      order by s2.c desc, s1.item_id desc, s1.created_at desc
    SQL
    jobs = ServiceJob.find_by_sql sql
    grouped_jobs = jobs.to_a.group_by(&:item_id)
    result[:jobs] = grouped_jobs
    result
  end
end
